const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const modulePath = process.argv[2] || '../hosts/nixos/inari/services/n8n/alert-router.cjs';
const { createRouter } = require(path.resolve(__dirname, modulePath));

const alert = (extra = {}) => ({source: 'test', severity: 'warning', title: 'Backup failed', fingerprint: 'backup', ...extra});
const instant = (iso) => () => new Date(iso);

async function setup(now, options = {}) {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'n8n-router-'));
  const statePath = path.join(dir, 'state.json');
  const sent = [];
  const router = createRouter({
    statePath,
    env: {NTFY_TOPIC: 'test', NTFY_URL: 'http://ntfy', NTFY_TOKEN: 'fixture'},
    now: instant(now),
    httpRequest: async (request) => {
      assert.equal(request.url, 'http://ntfy');
      if (options.fail) { options.fail = false; throw new Error('publish failed'); }
      sent.push(request.body);
      return {status: 200};
    },
  });
  return {dir, statePath, sent, router};
}

(async () => {
  let ctx = await setup('2026-01-05T22:00:00Z');
  assert.equal((await ctx.router.submit([alert()])).sent, 0, '23:00 Berlin warning waits');
  ctx.router = createRouter({statePath:ctx.statePath,env:{NTFY_TOPIC:'test',NTFY_URL:'http://ntfy',NTFY_TOKEN:'fixture'},now:instant('2026-01-06T05:55:00Z'),httpRequest:async req=>{ctx.sent.push(req.body);return {};}});
  assert.equal((await ctx.router.submit([])).sent, 0, '06:55 Berlin still quiet');
  ctx.router = createRouter({...ctx.router.options, statePath: ctx.statePath, env: {NTFY_TOPIC:'test',NTFY_URL:'http://ntfy',NTFY_TOKEN:'fixture'}, now: instant('2026-01-06T06:00:00Z'), httpRequest: async req => { ctx.sent.push(req.body); return {}; }});
  assert.equal((await ctx.router.submit([])).sent, 1, '07:00 flushes without another producer event');
  assert.equal((await ctx.router.submit([alert()])).sent, 0, 'repeat suppressed');
  ctx.router = createRouter({statePath:ctx.statePath,env:{NTFY_TOPIC:'test',NTFY_URL:'http://ntfy',NTFY_TOKEN:'fixture'},now:instant('2026-01-07T06:00:00Z'),httpRequest:async req=>{ctx.sent.push(req.body);return {};}});
  assert.equal((await ctx.router.submit([])).sent, 1, 'open problem gets daily reminder');
  ctx.router = createRouter({statePath:ctx.statePath,env:{NTFY_TOPIC:'test',NTFY_URL:'http://ntfy',NTFY_TOKEN:'fixture'},now:instant('2026-01-07T07:00:00Z'),httpRequest:async req=>{ctx.sent.push(req.body);return {};}});
  assert.equal((await ctx.router.submit([alert({resolved:true})])).sent, 1, 'recovery delivered');
  assert.equal((await ctx.router.submit([])).sent, 0, 'recovered problem stops reminders');

  ctx = await setup('2026-01-05T22:00:00Z');
  assert.equal((await ctx.router.submit([alert({severity:'critical'})])).sent, 1, 'urgent bypasses quiet hours');
  ctx.router = createRouter({statePath:ctx.statePath,env:{NTFY_TOPIC:'test',NTFY_URL:'http://ntfy',NTFY_TOKEN:'fixture'},now:instant('2026-01-05T23:00:00Z'),httpRequest:async req=>{ctx.sent.push(req.body);return {};}});
  assert.equal((await ctx.router.submit([alert({severity:'critical'})])).sent, 0, 'urgent repeats daily, not hourly');
  ctx.router = createRouter({statePath:ctx.statePath,env:{NTFY_TOPIC:'test',NTFY_URL:'http://ntfy',NTFY_TOKEN:'fixture'},now:instant('2026-01-06T00:00:00Z'),httpRequest:async req=>{ctx.sent.push(req.body);return {};}});
  await ctx.router.submit([alert({resolved:true})]);
  ctx.router = createRouter({statePath:ctx.statePath,env:{NTFY_TOPIC:'test',NTFY_URL:'http://ntfy',NTFY_TOKEN:'fixture'},now:instant('2026-01-06T06:00:00Z'),httpRequest:async req=>{ctx.sent.push(req.body);return {};}});
  assert.equal((await ctx.router.submit([])).sent, 1, 'recovery waits until morning');

  ctx = await setup('2026-01-05T22:00:00Z');
  await ctx.router.submit([alert()]);
  ctx.router = createRouter({statePath:ctx.statePath,env:{NTFY_TOPIC:'test',NTFY_URL:'http://ntfy',NTFY_TOKEN:'fixture'},now:instant('2026-01-06T00:00:00Z'),httpRequest:async req=>{ctx.sent.push(req.body);return {};}});
  await ctx.router.submit([alert({resolved:true})]);
  ctx.router = createRouter({statePath:ctx.statePath,env:{NTFY_TOPIC:'test',NTFY_URL:'http://ntfy',NTFY_TOKEN:'fixture'},now:instant('2026-01-06T06:00:00Z'),httpRequest:async req=>{ctx.sent.push(req.body);return {};}});
  assert.equal((await ctx.router.submit([])).sent, 0, 'unseen overnight problem resolved without noise');

  ctx = await setup('2026-01-05T10:00:00Z');
  await ctx.router.submit([alert()]);
  ctx.router = createRouter({statePath:ctx.statePath,env:{NTFY_TOPIC:'test',NTFY_URL:'http://ntfy',NTFY_TOKEN:'fixture'},now:instant('2026-01-05T22:00:00Z'),httpRequest:async req=>{ctx.sent.push(req.body);return {};}});
  assert.equal((await ctx.router.submit([alert({severity:'critical'})])).sent, 1, 'escalation bypasses suppression');

  ctx = await setup('2026-06-05T20:00:00Z');
  await ctx.router.submit([alert({event:true})]);
  ctx.router = createRouter({statePath:ctx.statePath,env:{NTFY_TOPIC:'test',NTFY_URL:'http://ntfy',NTFY_TOKEN:'fixture'},now:instant('2026-06-06T05:00:00Z'),httpRequest:async req=>{ctx.sent.push(req.body);return {};}});
  assert.equal((await ctx.router.submit([])).sent, 1, 'summer Berlin quiet hours use DST');
  ctx.router = createRouter({statePath:ctx.statePath,env:{NTFY_TOPIC:'test',NTFY_URL:'http://ntfy',NTFY_TOKEN:'fixture'},now:instant('2026-06-07T05:00:00Z'),httpRequest:async req=>{ctx.sent.push(req.body);return {};}});
  assert.equal((await ctx.router.submit([])).sent, 0, 'one-off events never get reminders');

  ctx = await setup('2026-01-05T10:00:00Z', {fail:true});
  assert.deepEqual(await ctx.router.submit([alert()]), {sent:0, failed:1, queued:1}, 'failed publish is reported, not thrown');
  ctx.router = createRouter({statePath:ctx.statePath,env:{NTFY_TOPIC:'test',NTFY_URL:'http://ntfy',NTFY_TOKEN:'fixture'},now:instant('2026-01-05T10:05:00Z'),httpRequest:async req=>{ctx.sent.push(req.body);return {};}});
  assert.equal((await ctx.router.submit([alert()])).sent, 1, 'failed publish does not suppress retry');

  ctx = await setup('2026-01-05T10:00:00Z');
  const [disk, backup, proto] = await Promise.all([
    ctx.router.submit([alert({fingerprint:'disk',title:'Disk'})]),
    ctx.router.submit([alert({fingerprint:'backup',title:'Backup'})]),
    ctx.router.submit([alert({fingerprint:'__proto__',title:'Prototype key'})]),
  ]);
  assert.equal(disk.sent + backup.sent + proto.sent, 3, 'concurrent submits both publish');
  const persisted = JSON.parse(await fs.readFile(ctx.statePath, 'utf8'));
  assert.deepEqual(Object.keys(persisted.alerts).sort(), ['__proto__', 'backup', 'disk'], 'concurrent submits persist all independent alerts');
  assert.equal(Object.hasOwn(persisted.alerts, '__proto__'), true, 'prototype-like fingerprints remain ordinary keys');

  ctx = await setup('2026-01-05T22:00:00Z');
  await ctx.router.submit([alert()]);
  const beforeRestart = JSON.parse(await fs.readFile(ctx.statePath, 'utf8'));
  assert.equal(beforeRestart.alerts.backup.pending, true, 'quiet-hour pending item is persisted across restart');
  ctx.router = createRouter({statePath:ctx.statePath,env:{NTFY_TOPIC:'test',NTFY_URL:'http://ntfy',NTFY_TOKEN:'fixture'},now:instant('2026-01-06T06:00:00Z'),httpRequest:async req=>{ctx.sent.push(req.body);return {};}});
  assert.equal((await ctx.router.submit([])).sent, 1, 'restarted router drains persisted morning item');

  // A receipt is on disk before ntfy is asked: if the publish (or the whole
  // process) dies, the alert is still there for the next drain.
  ctx = await setup('2026-01-05T10:00:00Z');
  ctx.router = createRouter({statePath:ctx.statePath,env:{NTFY_TOPIC:'test',NTFY_URL:'http://ntfy',NTFY_TOKEN:'fixture'},now:instant('2026-01-05T10:00:00Z'),httpRequest:async () => {
    const onDisk = JSON.parse(await fs.readFile(ctx.statePath, 'utf8'));
    assert.equal(onDisk.alerts.backup?.pending, true, 'alert persisted before publish');
    throw new Error('ntfy down');
  }});
  await ctx.router.submit([alert()]);
  ctx.router = createRouter({statePath:ctx.statePath,env:{NTFY_TOPIC:'test',NTFY_URL:'http://ntfy',NTFY_TOKEN:'fixture'},now:instant('2026-01-05T10:01:00Z'),httpRequest:async req=>{ctx.sent.push(req.body);return {};}});
  assert.equal((await ctx.router.submit([])).sent, 1, 'alert that failed to publish survives a restart');

  // One entry ntfy keeps rejecting does not hold back the others, and is
  // deferred after repeated failures instead of retried every minute.
  ctx = await setup('2026-01-05T10:00:00Z');
  const attempts = {poison: 0, good: 0};
  const rejecting = (iso) => createRouter({statePath:ctx.statePath,env:{NTFY_TOPIC:'test',NTFY_URL:'http://ntfy',NTFY_TOKEN:'fixture'},now:instant(iso),httpRequest:async req=>{
    const key = req.body.title.includes('Poison') ? 'poison' : 'good';
    attempts[key] += 1;
    return key === 'poison' ? {status: 400} : {status: 200};
  }});
  ctx.router = rejecting('2026-01-05T10:00:00Z');
  const mixed = await ctx.router.submit([alert({fingerprint:'poison',title:'Poison'}), alert({fingerprint:'good',title:'Good'})]);
  assert.deepEqual([mixed.sent, mixed.failed], [1, 1], 'rejected entry does not block the next one');
  for (let minute = 1; minute < 5; minute++) await ctx.router.submit([]);
  assert.equal(attempts.poison, 5, 'retried until the attempt limit');
  await ctx.router.submit([]);
  assert.equal(attempts.poison, 5, 'deferred after the attempt limit');
  ctx.router = rejecting('2026-01-05T11:01:00Z');
  await ctx.router.submit([]);
  assert.equal(attempts.poison, 6, 'retried again after the deferral');
  assert.equal(attempts.good, 1, 'delivered entry is not repeated');

  console.log('alert router: durable serialized policy, DST, reminders, escalation, recovery and retries passed');
})().catch(error => {console.error(error); process.exitCode = 1;});
