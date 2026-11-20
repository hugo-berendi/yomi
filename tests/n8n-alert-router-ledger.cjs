// Router ledger: normalization, outage and all-clear, cross-producer
// duplicates, and state left by earlier router versions. Run with:
//   node n8n-alert-router-ledger.cjs <alert-router.cjs>
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');

const routerPath = path.resolve(process.argv[2] || path.join(__dirname, '../hosts/nixos/inari/services/n8n/alert-router.cjs'));
const {createRouter, normalize} = require(routerPath);

const ENV = {NTFY_TOPIC: 'test', NTFY_URL: 'http://ntfy', NTFY_TOKEN: 'fixture'};
const MINUTE = 60 * 1000;
const down = (extra = {}) => ({source: 'services', host: 'inari', service: 'nextcloud', severity: 'warning',
  title: 'nextcloud is down', fingerprint: 'service:nextcloud', ...extra});

async function harness(start) {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'alert-ledger-'));
  const statePath = path.join(dir, 'state.json');
  const ctx = {statePath, time: Date.parse(start), pushes: []};
  ctx.make = () => createRouter({statePath, env: ENV, now: () => new Date(ctx.time),
    httpRequest: async (request) => {
      ctx.pushes.push(request.body);
      return {status: 200};
    }});
  ctx.router = ctx.make();
  ctx.at = (offsetMinutes) => {
    ctx.time = Date.parse(start) + offsetMinutes * MINUTE;
  };
  ctx.state = async () => JSON.parse(await fs.readFile(statePath, 'utf8'));
  return ctx;
}

(async () => {
  // {{{ Normalization
  const legacy = normalize({source: 'automation', title: 'Workflow failed', fingerprint: 'workflow:abc', event: true}, 1000);
  assert.deepEqual([legacy.host, legacy.service, legacy.kind, legacy.status], ['inari', 'n8n', 'event', 'firing'], 'legacy fields keep their meaning');
  assert.equal(normalize({source: 'services', title: 'x', fingerprint: 'service:immich'}, 1000).service, 'immich', 'service from legacy fingerprint');
  const explicit = normalize({source: 'grafana', host: 'Amaterasu', service: 'restic', title: 'backup overdue', status: 'resolved', occurredAt: '2026-01-05T09:00:00Z'}, Date.parse('2026-01-05T10:00:00Z'));
  assert.deepEqual([explicit.host, explicit.service, explicit.status, explicit.fingerprint], ['amaterasu', 'restic', 'resolved', 'amaterasu:restic:backup overdue'], 'unified fields and default fingerprint');
  assert.equal(explicit.occurredAt, Date.parse('2026-01-05T09:00:00Z'), 'producer time is kept');
  assert.equal(normalize({title: 'x', occurredAt: '2099-01-01T00:00:00Z'}, 5000).occurredAt, 5000, 'future producer time falls back to receipt');
  assert.throws(() => normalize({title: 'x', severity: 'page'}, 1), /severity/);
  // }}}

  // {{{ Outage then all-clear
  let ctx = await harness('2026-01-05T10:00:00Z');
  const result = await ctx.router.submit([down()]);
  assert.equal(result.sent, 1, 'outage pushes immediately');
  assert.match(ctx.pushes[0].title, /^\[WARN\] inari\/nextcloud · nextcloud is down$/, 'push title carries host and service');
  ctx.at(1);
  await ctx.router.submit([down()]);
  assert.equal(ctx.pushes.length, 1, 'duplicate report does not push again');
  let saved = await ctx.state();
  assert.equal(typeof saved.alerts['service:nextcloud'].ntfy.lastSent, 'number', 'push recorded');
  assert.equal(saved.targets.ntfy.lastSuccessAt, Date.parse('2026-01-05T10:00:00Z'));
  ctx.at(20);
  await ctx.router.submit([down({resolved: true})]);
  assert.match(ctx.pushes.at(-1).title, /^\[OK\] inari\/nextcloud/, 'all-clear pushed');
  saved = await ctx.state();
  assert.equal(saved.alerts['service:nextcloud'], undefined, 'finished incident leaves the ledger');
  ctx.at(21);
  await ctx.router.submit([down({resolved: true})]);
  assert.equal(ctx.pushes.length, 2, 'repeated all-clear is silent');
  assert.deepEqual(Object.keys(await ctx.router.status()).sort(), ['ntfy', 'open'], 'status reports ntfy only');
  // }}}

  // {{{ Quiet-hour flap: never pushed, nothing to clear
  ctx = await harness('2026-01-05T22:30:00Z');
  await ctx.router.submit([down()]);
  ctx.at(5);
  await ctx.router.submit([down({resolved: true})]);
  assert.equal(ctx.pushes.length, 0, 'night warning that clears is never pushed');
  assert.equal((await ctx.state()).alerts['service:nextcloud'], undefined, 'and leaves no entry behind');
  // }}}

  // {{{ Cross-producer duplicates
  ctx = await harness('2026-01-05T10:00:00Z');
  await ctx.router.submit([down({service: 'prometheus', title: 'prometheus is down', fingerprint: 'service:prometheus', severity: 'critical'})]);
  await ctx.router.submit([{source: 'watchdog', service: 'prometheus', severity: 'warning', title: 'Prometheus not ready', fingerprint: 'watchdog:prometheus'}]);
  await ctx.router.submit([{source: 'grafana', service: 'prometheus', severity: 'warning', title: 'Prometheus target down', fingerprint: 'grafana:abc'}]);
  assert.equal(ctx.pushes.length, 1, 'same host and service from other producers is absorbed');
  await ctx.router.submit([{source: 'grafana', service: 'prometheus', severity: 'critical', title: 'Prometheus target down', fingerprint: 'grafana:abc'}]);
  assert.equal(ctx.pushes.length, 1, 'equal severity stays absorbed');
  ctx.at(10);
  await ctx.router.submit([down({service: 'prometheus', title: 'prometheus is down', fingerprint: 'service:prometheus', resolved: true})]);
  assert.equal(ctx.pushes.length, 3, 'primary clears and only the most severe still-firing related alert pages');
  assert.match(ctx.pushes[2].title, /^\[CRIT\] inari\/prometheus · Prometheus target down$/);
  ctx = await harness('2026-01-05T10:00:00Z');
  await ctx.router.submit([{source: 'automation', service: 'n8n', title: 'A failed', fingerprint: 'workflow:a'}]);
  await ctx.router.submit([{source: 'automation', service: 'n8n', title: 'B failed', fingerprint: 'workflow:b'}]);
  assert.equal(ctx.pushes.length, 2, 'same producer is never absorbed');
  // }}}

  // {{{ Version 1 state
  ctx = await harness('2026-01-05T10:00:00Z');
  await fs.writeFile(ctx.statePath, JSON.stringify({alerts: {backup: {severity: 'warning', lastSeen: ctx.time - MINUTE,
    lastSent: ctx.time - MINUTE, pending: false, alert: {source: 'test', title: 'Backup failed', message: '', severity: 'warning',
      url: null, tags: [], event: false, resolved: false}}}}));
  ctx.router = ctx.make();
  await ctx.router.submit([{source: 'test', title: 'Backup failed', fingerprint: 'backup'}]);
  assert.equal(ctx.pushes.length, 0, 'migrated suppression holds');
  assert.equal((await ctx.state()).version, 2);
  // }}}

  // {{{ Version 2 state from the removed triage target
  ctx = await harness('2026-01-05T10:00:00Z');
  await ctx.router.submit([down()]);
  const withTriage = await ctx.state();
  withTriage.alerts['service:nextcloud'].hermes = {pending: true, phase: 'firing', state: 'inflight', triaged: false};
  withTriage.triage = {inflight: {id: 'alert-x', items: ['service:nextcloud']}, sent: []};
  withTriage.targets.hermes = {lastError: 'fetch failed'};
  await fs.writeFile(ctx.statePath, JSON.stringify(withTriage));
  ctx.router = ctx.make();
  ctx.at(1);
  await ctx.router.submit([down()]);
  assert.equal(ctx.pushes.length, 1, 'suppression survives the old ledger');
  saved = await ctx.state();
  assert.equal(saved.alerts['service:nextcloud'].hermes, undefined, 'per-alert triage ledger dropped');
  assert.equal(saved.triage, undefined, 'triage queue dropped');
  assert.equal(saved.targets.hermes, undefined, 'triage target status dropped');
  ctx.at(5);
  await ctx.router.submit([down({resolved: true})]);
  assert.equal(ctx.pushes.length, 2, 'all-clear still pushed');
  assert.equal((await ctx.state()).alerts['service:nextcloud'], undefined, 'and the entry is pruned');
  // }}}

  console.log('alert router ledger: normalization, all-clear, quiet flap, duplicates and old state passed');
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
