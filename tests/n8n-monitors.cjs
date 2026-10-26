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
  console.log('CI and service monitor policy passed');
})().catch(error => {console.error(error);process.exitCode=1;});
