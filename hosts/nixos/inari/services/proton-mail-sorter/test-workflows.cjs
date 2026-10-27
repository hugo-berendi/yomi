const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

async function main() {
  const directory = process.argv[2];
  const workflowIds = new Set();
  // The sorter was published in ea261b3; the mark-read pass stays off.
  const expectedActive = {'proton-mail-sorter.json': true, 'proton-mark-read.json': false};
  for (const [filename, active] of Object.entries(expectedActive)) {
    const workflow = JSON.parse(fs.readFileSync(path.join(directory, filename), 'utf8'));
    assert.match(workflow.id, /^[a-zA-Z0-9]{16}$/);
    assert(!workflowIds.has(workflow.id));
    workflowIds.add(workflow.id);
    assert.equal(workflow.active, active, `${filename} active`);
    assert.deepEqual(workflow.nodeGroups, []);
    assert.equal(workflow.settings.saveDataSuccessExecution, 'none');
    assert.equal(workflow.settings.saveDataErrorExecution, 'none');
    assert.equal(workflow.settings.timezone, 'Europe/Berlin');
    const names = new Set(workflow.nodes.map(node => node.name));
    assert.equal(names.size, workflow.nodes.length);
    assert.equal(new Set(workflow.nodes.map(node => node.id)).size, workflow.nodes.length);
    for (const [name, connections] of Object.entries(workflow.connections)) {
      assert(names.has(name));
      for (const branch of connections.main) for (const link of branch) assert(names.has(link.node));
    }
    const http = workflow.nodes.find(node => node.type === 'n8n-nodes-base.httpRequest');
    assert.equal(http.typeVersion, 4.2);
    assert.equal(http.parameters.authentication, 'genericCredentialType');
    assert.equal(http.parameters.genericAuthType, 'httpHeaderAuth');
    assert.equal(http.parameters.method, 'POST');
    assert(http.credentials.httpHeaderAuth.id);
    assert(http.parameters.url.includes('$env.PROTON_SORTER_URL'));
    assert(!http.parameters.sendBody);
    const scheduled = workflow.nodes.filter(node => node.type === 'n8n-nodes-base.scheduleTrigger');
    assert.equal(scheduled.length, filename === 'proton-mail-sorter.json' ? 1 : 0);
    if (scheduled.length) assert.equal(scheduled[0].parameters.rule.interval[0].expression, '*/10 * * * *');
    const code = workflow.nodes.find(node => node.type === 'n8n-nodes-base.code').parameters.jsCode;
    assert(!code.includes('process.env'));
    for (const result of [{started: true, dryRun: true}, {started: false, busy: true}, {previous: {status: 'failed'}}]) {
      const context = vm.createContext({$input: {first: () => ({json: result})}});
      const promise = vm.runInContext(`(async function(){${code}\n})()`, context);
      if (result.previous?.status === 'failed') await assert.rejects(promise, /Previous Proton sorter job failed/);
      else assert.deepEqual(JSON.parse(JSON.stringify(await promise)), [{json: result}]);
    }
    console.log(`PASS: ${filename}: IDs, connections, pinned node versions, private HTTP credential, schedule and sandboxed Code node`);
  }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
