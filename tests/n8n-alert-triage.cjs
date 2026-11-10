// Per-target delivery: ntfy and Hermes triage, outage, all-clear, duplicates,
// restarts and an unavailable Hermes. Run with the router and triage modules:
//   node n8n-alert-triage.cjs <alert-router.cjs> <alert-triage.cjs>
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs/promises');
const http = require('node:http');
const os = require('node:os');
const path = require('node:path');
const {once} = require('node:events');

const routerPath = path.resolve(process.argv[2] || path.join(__dirname, '../hosts/nixos/inari/services/n8n/alert-router.cjs'));
const triagePath = path.resolve(process.argv[3] || path.join(path.dirname(routerPath), 'alert-triage.cjs'));
const {createRouter, normalize} = require(routerPath);
const {createTriage, sanitize, configuration} = require(triagePath);

const ENV = {NTFY_TOPIC: 'test', NTFY_URL: 'http://ntfy', NTFY_TOKEN: 'fixture'};
const MINUTE = 60 * 1000;
const down = (extra = {}) => ({source: 'services', host: 'inari', service: 'nextcloud', severity: 'warning',
  title: 'nextcloud is down', fingerprint: 'service:nextcloud', ...extra});

async function harness(start, {hermes = 'ok'} = {}) {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'alert-triage-'));
  const statePath = path.join(dir, 'state.json');
  const ctx = {dir, statePath, time: Date.parse(start), pushes: [], deliveries: [], hermes};
  ctx.triage = {
    deliver: async (delivery, items, others) => {
      ctx.deliveries.push({id: delivery.id, phase: delivery.phase, items: items.map((entry) => entry.alert.fingerprint),
        others: others.map((entry) => entry.alert.fingerprint)});
      if (ctx.hermes === 'down') throw new Error('connect ECONNREFUSED 127.0.0.1:8644');
      if (ctx.hermes === 'hang') return new Promise(() => {});
      return {ok: true, status: 202};
    },
  };
  ctx.make = () => createRouter({statePath, env: ENV, now: () => new Date(ctx.time), triage: ctx.triage,
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

  // {{{ Outage then all-clear, Hermes up
  let ctx = await harness('2026-01-05T10:00:00Z');
  let result = await ctx.router.submit([down()]);
  assert.equal(result.sent, 1, 'outage pushes immediately');
  assert.match(ctx.pushes[0].title, /^\[WARN\] inari\/nextcloud · nextcloud is down$/, 'push title carries host and service');
  await ctx.router.runTriage();
  assert.equal(ctx.deliveries.length, 0, 'triage waits for the settle window');
  ctx.at(1);
  await ctx.router.submit([down()]);
  assert.equal(ctx.pushes.length, 1, 'duplicate report does not push again');
  ctx.at(3);
  await ctx.router.submit([]);
  await ctx.router.runTriage();
  assert.deepEqual(ctx.deliveries.map((d) => [d.phase, d.items]), [['firing', ['service:nextcloud']]], 'one triage after the settle window');
  let saved = await ctx.state();
  assert.equal(saved.alerts['service:nextcloud'].hermes.triaged, true, 'triage recorded per target');
  assert.equal(typeof saved.alerts['service:nextcloud'].ntfy.lastSent, 'number', 'push recorded per target');
  assert.equal(saved.targets.ntfy.lastSuccessAt, Date.parse('2026-01-05T10:00:00Z'));
  ctx.at(4);
  await ctx.router.submit([down()]);
  await ctx.router.runTriage();
  assert.equal(ctx.deliveries.length, 1, 'duplicate report does not triage again');
  ctx.at(20);
  await ctx.router.submit([down({resolved: true})]);
  assert.match(ctx.pushes.at(-1).title, /^\[OK\] inari\/nextcloud/, 'all-clear pushed');
  await ctx.router.runTriage();
  assert.deepEqual(ctx.deliveries.at(-1).phase, 'resolved', 'all-clear also reaches the chat');
  saved = await ctx.state();
  assert.equal(saved.alerts['service:nextcloud'], undefined, 'finished incident leaves the ledger');
  ctx.at(21);
  await ctx.router.submit([down({resolved: true})]);
  await ctx.router.runTriage();
  assert.equal(ctx.pushes.length, 2, 'repeated all-clear is silent');
  assert.equal(ctx.deliveries.length, 2, 'repeated all-clear is not triaged');
  // }}}

  // {{{ Flap inside the settle window: push yes, model no
  ctx = await harness('2026-01-05T10:00:00Z');
  await ctx.router.submit([down()]);
  ctx.at(1);
  await ctx.router.submit([down({resolved: true})]);
  ctx.at(5);
  await ctx.router.runTriage();
  assert.equal(ctx.deliveries.length, 0, 'flap is not triaged');
  assert.equal(ctx.pushes.length, 2, 'flap is pushed and cleared');
  // }}}

  // {{{ Hermes down: ntfy unaffected, retries keep the delivery id, give up
  ctx = await harness('2026-01-05T10:00:00Z', {hermes: 'down'});
  await ctx.router.submit([down()]);
  ctx.at(3);
  await ctx.router.submit([]);
  await ctx.router.runTriage();
  assert.equal(ctx.deliveries.length, 1, 'first attempt');
  saved = await ctx.state();
  assert.equal(saved.triage.inflight.attempts, 1, 'failed attempt is persisted');
  assert.match(saved.targets.hermes.lastError, /ECONNREFUSED/, 'hermes failure recorded separately');
  assert.equal(saved.targets.ntfy.lastError, undefined, 'ntfy has no error');
  ctx.at(3.5);
  await ctx.router.runTriage();
  assert.equal(ctx.deliveries.length, 1, 'backoff respected');
  ctx.at(4.1);
  const pushesBefore = ctx.pushes.length;
  result = await ctx.router.submit([down({service: 'immich', title: 'immich is down', fingerprint: 'service:immich'})]);
  assert.equal(result.sent, 1, 'a new alert is pushed while Hermes is down');
  assert.equal(ctx.pushes.length, pushesBefore + 1);
  await ctx.router.runTriage();
  assert.equal(ctx.deliveries[1].id, ctx.deliveries[0].id, 'retry reuses the delivery id');
  for (let minute = 5; minute < 400; minute += 5) {
    ctx.at(minute);
    await ctx.router.runTriage();
  }
  saved = await ctx.state();
  assert.equal(saved.alerts['service:nextcloud'].hermes.state, 'abandoned', 'gives up eventually');
  const perDelivery = ctx.deliveries.reduce((counts, d) => ({...counts, [d.id]: (counts[d.id] ?? 0) + 1}), {});
  assert(Object.values(perDelivery).every((count) => count <= 8), `bounded attempts per delivery ${JSON.stringify(perDelivery)}`);
  assert.equal(saved.triage.inflight, null, 'nothing left in flight after giving up');
  // }}}

  // {{{ Hermes hangs: the push path does not wait for it
  ctx = await harness('2026-01-05T10:00:00Z', {hermes: 'hang'});
  await ctx.router.submit([down()]);
  ctx.at(3);
  await ctx.router.submit([]);
  ctx.router.runTriage();
  const started = Date.now();
  result = await Promise.race([
    ctx.router.submit([down({service: 'immich', title: 'immich is down', fingerprint: 'service:immich'})]),
    new Promise((resolve) => setTimeout(() => resolve('blocked'), 2000)),
  ]);
  assert.notEqual(result, 'blocked', 'submit completes while a triage hangs');
  assert.equal(result.sent, 1);
  assert(Date.now() - started < 1000);
  // }}}

  // {{{ Restart with a delivery in flight
  ctx = await harness('2026-01-05T10:00:00Z', {hermes: 'hang'});
  await ctx.router.submit([down()]);
  ctx.at(3);
  await ctx.router.submit([]);
  ctx.router.runTriage();
  await new Promise((resolve) => setTimeout(resolve, 50));
  const firstId = ctx.deliveries[0].id;
  saved = await ctx.state();
  assert.equal(saved.triage.inflight.id, firstId, 'in-flight delivery persisted before sending');
  ctx.hermes = 'ok';
  ctx.router = ctx.make();
  ctx.at(4);
  await ctx.router.runTriage();
  assert.equal(ctx.deliveries.length, 1, 'a recent in-flight delivery is not resent at once');
  ctx.at(9);
  await ctx.router.runTriage();
  assert.equal(ctx.deliveries[1].id, firstId, 'after restart the same delivery id is resent');
  saved = await ctx.state();
  assert.equal(saved.alerts['service:nextcloud'].hermes.triaged, true);
  ctx.at(10);
  await ctx.router.submit([down()]);
  assert.equal(ctx.pushes.length, 1, 'restart does not repeat the push');
  // }}}

  // {{{ Cross-producer duplicates: one push, one triage, related context
  ctx = await harness('2026-01-05T10:00:00Z');
  await ctx.router.submit([down({service: 'prometheus', title: 'prometheus is down', fingerprint: 'service:prometheus', severity: 'critical'})]);
  await ctx.router.submit([{source: 'watchdog', service: 'prometheus', severity: 'warning', title: 'Prometheus not ready', fingerprint: 'watchdog:prometheus'}]);
  await ctx.router.submit([{source: 'grafana', service: 'prometheus', severity: 'warning', title: 'Prometheus target down', fingerprint: 'grafana:abc'}]);
  assert.equal(ctx.pushes.length, 1, 'same host and service from other producers is absorbed');
  ctx.at(3);
  await ctx.router.submit([]);
  await ctx.router.runTriage();
  assert.deepEqual(ctx.deliveries[0].items, ['service:prometheus'], 'only the paging alert is triaged');
  assert.deepEqual(ctx.deliveries[0].others.sort(), ['grafana:abc', 'watchdog:prometheus'], 'absorbed alerts appear as related context');
  await ctx.router.submit([{source: 'grafana', service: 'prometheus', severity: 'critical', title: 'Prometheus target down', fingerprint: 'grafana:abc'}]);
  assert.equal(ctx.pushes.length, 1, 'equal severity stays absorbed');
  ctx.at(10);
  await ctx.router.submit([down({service: 'prometheus', title: 'prometheus is down', fingerprint: 'service:prometheus', resolved: true})]);
  assert.equal(ctx.pushes.length, 3, 'primary clears and only the most severe still-firing related alert pages');
  assert.match(ctx.pushes[2].title, /^\[CRIT\] inari\/prometheus · Prometheus target down$/);
  // Two different workflows of the same producer are separate problems.
  ctx = await harness('2026-01-05T10:00:00Z');
  await ctx.router.submit([{source: 'automation', service: 'n8n', title: 'A failed', fingerprint: 'workflow:a'}]);
  await ctx.router.submit([{source: 'automation', service: 'n8n', title: 'B failed', fingerprint: 'workflow:b'}]);
  assert.equal(ctx.pushes.length, 2, 'same producer is never absorbed');
  // }}}

  // {{{ Burst: one batch, rate limit
  ctx = await harness('2026-01-05T10:00:00Z');
  await ctx.router.submit(Array.from({length: 12}, (_, i) => down({service: `svc${i}`, title: `svc${i} is down`, fingerprint: `service:svc${i}`})));
  ctx.at(3);
  await ctx.router.submit([]);
  await ctx.router.runTriage();
  assert.deepEqual(ctx.deliveries.map((d) => d.items.length), [8, 4], 'burst is batched');
  ctx = await harness('2026-01-05T10:00:00Z');
  for (let i = 0; i < 8; i++) {
    ctx.at(i * 4);
    await ctx.router.submit([down({service: `s${i}`, title: `s${i} down`, fingerprint: `service:s${i}`})]);
    ctx.at(i * 4 + 3);
    await ctx.router.runTriage();
  }
  assert.equal(ctx.deliveries.length, 6, 'at most six triage deliveries an hour');
  ctx.at(95);
  await ctx.router.runTriage();
  assert.deepEqual(ctx.deliveries.slice(6).map((d) => d.items.length), [2], 'deferred alerts follow together once the hour has passed');
  // }}}

  // {{{ Quiet hours and events
  ctx = await harness('2026-01-05T22:30:00Z');
  await ctx.router.submit([down()]);
  ctx.at(5);
  await ctx.router.runTriage();
  assert.equal(ctx.pushes.length + ctx.deliveries.length, 0, 'night warning waits on both targets');
  await ctx.router.submit([down({severity: 'critical'})]);
  ctx.at(8);
  await ctx.router.runTriage();
  assert.equal(ctx.pushes.length, 1, 'escalation to critical pushes at night');
  assert.equal(ctx.deliveries.length, 1, 'and is triaged at night');
  ctx = await harness('2026-01-05T10:00:00Z');
  await ctx.router.submit([{source: 'automation', title: 'Workflow failed', fingerprint: 'workflow:x', event: true}]);
  ctx.at(5);
  await ctx.router.runTriage();
  assert.equal(ctx.deliveries.length, 0, 'one-off events are not triaged');
  ctx = await harness('2026-01-05T10:00:00Z');
  await ctx.router.submit([down({severity: 'info'})]);
  ctx.at(5);
  await ctx.router.runTriage();
  assert.equal(ctx.deliveries.length, 0, 'info is not triaged');
  // }}}

  // {{{ No triage configured
  ctx = await harness('2026-01-05T10:00:00Z');
  ctx.router = createRouter({statePath: ctx.statePath, env: ENV, now: () => new Date(ctx.time), triage: null,
    httpRequest: async (request) => (ctx.pushes.push(request.body), {status: 200})});
  await ctx.router.submit([down()]);
  ctx.at(3);
  await ctx.router.runTriage();
  saved = await ctx.state();
  assert.equal(saved.alerts['service:nextcloud'].hermes.state, 'disabled');
  ctx.at(10);
  await ctx.router.submit([down({resolved: true})]);
  assert.equal((await ctx.state()).alerts['service:nextcloud'], undefined, 'disabled target does not keep entries alive');
  // }}}

  // {{{ Version 1 state
  ctx = await harness('2026-01-05T10:00:00Z');
  await fs.writeFile(ctx.statePath, JSON.stringify({alerts: {backup: {severity: 'warning', lastSeen: ctx.time - MINUTE,
    lastSent: ctx.time - MINUTE, pending: false, alert: {source: 'test', title: 'Backup failed', message: '', severity: 'warning',
      url: null, tags: [], event: false, resolved: false}}}}));
  ctx.router = ctx.make();
  await ctx.router.submit([{source: 'test', title: 'Backup failed', fingerprint: 'backup'}]);
  assert.equal(ctx.pushes.length, 0, 'migrated suppression holds');
  ctx.at(5);
  await ctx.router.runTriage();
  assert.equal(ctx.deliveries.length, 0, 'migrated alerts are not triaged after the fact');
  assert.equal((await ctx.state()).version, 2);
  // }}}

  // {{{ Sanitizer
  const dirty = 'GET /api?token=abc123 Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U password=hunter2 mail hugo@example.org key 3f9a8b7c6d5e4f3a2b1c0d9e8f7a6b5c4d3e2f1a';
  const cleaned = sanitize(dirty, 1000);
  for (const secret of ['abc123', 'hunter2', 'hugo@example.org', 'eyJhbGci', '3f9a8b7c6d5e4f3a2b1c']) assert(!cleaned.includes(secret), `${secret} removed: ${cleaned}`);
  assert.match(cleaned, /password=\[entfernt\]/);
  assert(sanitize('x'.repeat(500)).length <= 240, 'line length capped');
  assert.equal(sanitize('ok \u001b[31mred\u001b[0m'), 'ok red', 'terminal escapes stripped');
  // }}}

  // {{{ Configuration changes between generations
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'generations-'));
  for (const [gen, unitTarget] of [['old', '/nix/store/a-unit-n8n.service/n8n.service'], ['new', '/nix/store/b-unit-n8n.service/n8n.service']]) {
    await fs.mkdir(path.join(root, gen, 'etc/systemd/system/gatus.service.d'), {recursive: true});
    await fs.symlink(unitTarget, path.join(root, gen, 'etc/systemd/system/n8n.service'));
    await fs.symlink('/nix/store/same-unit/loki.service', path.join(root, gen, 'etc/systemd/system/loki.service'));
    await fs.symlink(`/nix/store/${gen}-override`, path.join(root, gen, 'etc/systemd/system/gatus.service.d/overrides.conf'));
  }
  const profiles = path.join(root, 'profiles');
  await fs.mkdir(profiles);
  await fs.symlink(path.join(root, 'old'), path.join(profiles, 'system-41-link'));
  await fs.symlink(path.join(root, 'new'), path.join(profiles, 'system-42-link'));
  const config = await configuration(profiles, path.join(root, 'new'), Date.now());
  assert.deepEqual(config.changed, ['gatus.service', 'n8n.service'], 'changed units and overrides, not untouched ones');
  assert.match(config.lines[0], /Aktive Generation 42/);
  // }}}

  // {{{ Signed delivery to a Hermes-shaped endpoint
  const secretDir = await fs.mkdtemp(path.join(os.tmpdir(), 'hermes-secret-'));
  const secret = crypto.randomBytes(32).toString('base64');
  await fs.writeFile(path.join(secretDir, 'hermes-webhook'), secret + '\n');
  const received = [];
  const seen = new Set();
  const server = http.createServer(async (request, response) => {
    let body = '';
    for await (const chunk of request) body += chunk;
    const timestamp = request.headers['x-webhook-timestamp'];
    const expected = crypto.createHmac('sha256', secret).update(`${timestamp}.${body}`).digest('hex');
    if (request.headers['x-webhook-signature-v2'] !== expected) return response.writeHead(401).end();
    const id = request.headers['x-request-id'];
    if (seen.has(id)) return response.writeHead(200).end('{"status":"duplicate"}');
    seen.add(id);
    received.push({route: request.url, body: JSON.parse(body)});
    response.writeHead(202).end('{"status":"accepted"}');
  }).listen(0, '127.0.0.1');
  await once(server, 'listening');
  const dead = 'http://127.0.0.1:9';
  const triage = await createTriage({env: {
    HERMES_WEBHOOK_URL: `http://127.0.0.1:${server.address().port}/webhooks`, CREDENTIALS_DIRECTORY: secretDir,
    PROMETHEUS_URL: dead, LOKI_URL: dead, SYSTEM_PROFILES: profiles, CURRENT_SYSTEM: path.join(root, 'new'),
  }});
  assert(triage, 'configured triage');
  const entry = {alert: normalize(down(), Date.now()), firstSeen: Date.now(), lastChange: Date.now()};
  const delivery = {id: 'alert-test', phase: 'firing', items: ['service:nextcloud']};
  assert.deepEqual(await triage.deliver(delivery, [entry], []), {ok: true, status: 202}, 'signed delivery accepted');
  assert.deepEqual(await triage.deliver(delivery, [entry], []), {ok: true, status: 200}, 'duplicate counts as delivered');
  assert.equal(received.length, 1);
  assert.equal(received[0].route, '/webhooks/alert-triage');
  assert.match(received[0].body.context, /Fehlende Messdaten|Prometheus nicht erreichbar/, 'missing metrics are stated, not hidden');
  assert.match(received[0].body.context, /Loki nicht abfragbar/, 'unreachable Loki is stated');
  assert.match(received[0].body.context, /Generation 42/, 'configuration context included');
  const resolvedEntry = {...entry, alert: {...entry.alert, status: 'resolved'}, resolvedAt: Date.now()};
  assert.equal((await triage.deliver({id: 'alert-clear', phase: 'resolved', items: []}, [resolvedEntry], [])).ok, true);
  assert.equal(received[1].route, '/webhooks/alert-notice');
  assert.match(received[1].body.message, /Entwarnung inari\/nextcloud/);
  const forged = await createTriage({env: {HERMES_WEBHOOK_URL: `http://127.0.0.1:${server.address().port}/webhooks`,
    HERMES_WEBHOOK_SECRET_FILE: path.join(secretDir, 'hermes-webhook'), PROMETHEUS_URL: dead, LOKI_URL: dead,
    SYSTEM_PROFILES: profiles, CURRENT_SYSTEM: path.join(root, 'new')}});
  await fs.writeFile(path.join(secretDir, 'other'), crypto.randomBytes(32).toString('base64'));
  const wrong = await createTriage({env: {HERMES_WEBHOOK_URL: `http://127.0.0.1:${server.address().port}/webhooks`,
    HERMES_WEBHOOK_SECRET_FILE: path.join(secretDir, 'other'), PROMETHEUS_URL: dead, LOKI_URL: dead,
    SYSTEM_PROFILES: profiles, CURRENT_SYSTEM: path.join(root, 'new')}});
  assert(forged);
  assert.equal((await wrong.deliver({id: 'alert-forged', phase: 'firing'}, [entry], [])).status, 401, 'wrong secret is rejected');
  assert.equal(await createTriage({env: {HERMES_WEBHOOK_URL: 'http://x', HERMES_WEBHOOK_SECRET_FILE: path.join(secretDir, 'missing')}}), null, 'no secret, no triage');
  const unreachable = await createTriage({env: {HERMES_WEBHOOK_URL: dead + '/webhooks', CREDENTIALS_DIRECTORY: secretDir,
    PROMETHEUS_URL: dead, LOKI_URL: dead, SYSTEM_PROFILES: profiles, CURRENT_SYSTEM: path.join(root, 'new')}});
  await assert.rejects(unreachable.deliver(delivery, [entry], []), 'unreachable Hermes surfaces as an error for the router to retry');
  server.close();
  // }}}

  console.log('alert triage: per-target ledger, outage, all-clear, duplicates, restart, Hermes down, sanitizing and signing passed');
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
