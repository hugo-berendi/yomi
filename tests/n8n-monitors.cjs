const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const root = process.argv[2] || path.join(__dirname, '../hosts/nixos/inari/services/n8n/workflows');
async function run(file, data, state = {}) {
  const workflow = JSON.parse(fs.readFileSync(path.join(root, file + '.json')));
  const code = workflow.nodes.find(n => n.type === 'n8n-nodes-base.code').parameters.jsCode;
  return vm.runInNewContext(`(async function(){\n${code}\n}).call({helpers})`, {
    $getWorkflowStaticData: () => state,
    helpers: {httpRequest: async request => {
      assert.equal(request.method, 'GET');
      return data;
    }},
  });
}
(async () => {
  const tasks = {workflow_runs: [
    {id: 4, workflow_id: 'check', head_branch: 'feature', status: 'failure'},
    {id: 3, workflow_id: 'check', head_branch: 'main', status: 'running'},
    {id: 2, workflow_id: 'check', head_branch: 'main', status: 'failure'},
    {id: 1, workflow_id: 'check', head_branch: 'main', status: 'success'},
  ]};
  const broken = await run('forgejo-ci', tasks);
  assert.equal(broken.length, 1);
  assert.equal(broken[0].json.resolved, false, 'a running build does not hide a failed main build');
  assert.match(broken[0].json.fingerprint, /check/);
  tasks.workflow_runs.unshift({id: 5, workflow_id: 'check', head_branch: 'main', status: 'success'});
  assert.equal((await run('forgejo-ci', tasks))[0].json.resolved, true, 'passing main build resolves problem');
  const ci = JSON.parse(fs.readFileSync(path.join(root, 'forgejo-ci.json')));
  assert(!ci.nodes.some(n => n.type === 'n8n-nodes-base.emailSend'), 'no CI email');
  const status = success => ({name: 'immich', results: [1,2,3].map((_,i) => ({success,timestamp:`2026-01-01T00:0${i}:00Z`}))});
  assert.equal((await run('service-status', [status(false)]))[0].json.severity, 'warning', 'ordinary application outage respects quiet hours');
  assert.equal((await run('service-status', [{...status(false),name:'prometheus'}]))[0].json.severity, 'critical', 'monitoring infrastructure outage bypasses quiet hours');
  assert.equal((await run('service-status', [status(true)]))[0].json.resolved, true);
  assert.equal((await run('service-status', [{name:'flapping',results:[{success:true},{success:false}]}])).length, 0, 'single failed probe does not page');
  const outage = (await run('service-status', [status(false)]))[0].json;
  assert.deepEqual([outage.host, outage.service, outage.occurredAt], ['inari', 'immich', '2026-01-01T00:00:00Z'], 'probe outage carries host, service and onset');
  const bridge = JSON.parse(fs.readFileSync(path.join(root, 'grafana-bridge.json')));
  const translate = bridge.nodes.find(n => n.name === 'Translate to spine format').parameters.jsCode;
  const grafana = (body) => vm.runInNewContext(`(function(){\n${translate}\n})()`, {$input: {first: () => ({json: {body}})}});
  const [fired] = grafana({status: 'firing', alerts: [{status: 'firing', fingerprint: 'f1', startsAt: '2026-01-01T10:00:00Z',
    endsAt: '0001-01-01T00:00:00Z', valueString: '[ var=A value=1 ]',
    labels: {alertname: 'ZFS pool degraded', severity: 'critical', service: 'zfs', pool: 'raid5pool'}, annotations: {summary: 'degraded'}}]});
  assert.deepEqual([fired.json.host, fired.json.service, fired.json.occurredAt, fired.json.labels.pool], ['inari', 'zfs', '2026-01-01T10:00:00Z', 'raid5pool'], 'Grafana alert carries unified fields');
  const [cleared] = grafana({status: 'resolved', alerts: [{status: 'resolved', fingerprint: 'f1', endsAt: '2026-01-01T11:00:00Z', labels: {alertname: 'Prometheus target down', job: 'loki'}}]});
  assert.deepEqual([cleared.json.service, cleared.json.resolved, cleared.json.occurredAt], ['loki', true, '2026-01-01T11:00:00Z'], 'scrape job names the service, all-clear has its end time');
  console.log('CI and service monitor policy passed');
})().catch(error => {console.error(error);process.exitCode=1;});
