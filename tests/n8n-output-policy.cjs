const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const root = process.argv[2] || path.join(__dirname, '..', 'hosts/nixos/inari/services/n8n/workflows');
const workflow = (name) => JSON.parse(fs.readFileSync(path.join(root, `${name}.json`), 'utf8'));
const nodeCode = (name, nodeName) => workflow(name).nodes.find((node) => node.name === nodeName).parameters.jsCode;

async function run(code, {input = [], state = {}, env = {}, http = async () => ({}), linked = {}} = {}) {
  const sandbox = vm.createContext({
    __isExecutionContext: true,
    $env: env,
    $input: { all: () => input, first: () => input[0] },
    $getWorkflowStaticData: () => state,
    $: (name) => ({ first: () => ({ json: linked[name] }) }),
    Date,
    console,
  });
  sandbox.__this = { helpers: { httpRequest: http } };
  return new vm.Script(`(async function() { ${code}\n}).call(__this)`).runInContext(sandbox);
}

(async () => {
  const healthyProm = { data: { result: [
    ['memory_pct', '45'], ['load1', '1'], ['cpu_count', '8'], ['failed_units', '0'],
    ['disk_pct', '30'], ['zfs_health', '0'], ['smart_status', '1'],
  ].map(([metric, value]) => ({ metric: { metric, mountpoint: '/', pool: 'tank', device: 'sda' }, value: [0, value] })) } };
  const healthy = await run(nodeCode('health-monitor', 'Gesundheitsdaten sammeln'), { http: async ({url}) => url.includes('prometheus') || url.includes(':8451') ? healthyProm : [] });
  assert.equal(healthy.length, 0, 'healthy host produces no email item');
  const serviceProblem = await run(nodeCode('health-monitor', 'Gesundheitsdaten sammeln'), {
    http: async ({url}) => url.includes(':8451') ? healthyProm : [{name: 'immich', results: [{success: false}]}],
  });
  assert.equal(serviceProblem.length, 1, 'failed service makes the health email actionable');

  const problemProm = structuredClone(healthyProm);
  problemProm.data.result.find((s) => s.metric.metric === 'failed_units').value[1] = '1';
  const problem = await run(nodeCode('health-monitor', 'Gesundheitsdaten sammeln'), { http: async ({url}) => url.includes(':8451') ? problemProm : [] });
  assert.equal(problem.length, 1, 'problem host produces a digest email item');
  assert.match(problem[0].json.subject, /ACTION REQUIRED/);

  let repairCalled = false;
  const immich = await run(nodeCode('immich-maintenance', 'Repair metadata and collect duplicates'), {
    env: { IMMICH_API_KEY: 'test' },
    http: async ({method, url}) => {
      if (method === 'PUT') { repairCalled = true; return {}; }
      assert.match(url, /duplicates/); return [];
    },
  });
  assert.equal(repairCalled, true, 'metadata repair still runs with no duplicate groups');
  assert.equal(immich.length, 0, 'no duplicate groups produce no email item');

  const baseline = { requests: { '10': {requestStatus: 2, mediaStatus: 2, type: 'movie', tmdbId: 44} } };
  const trackerCode = nodeCode('jellyseerr-tracker', 'Check request changes');
  const seeded = await run(trackerCode, {state: {}, env: {JELLYSEERR_API_KEY: 'test'}, http: async () => ({results: [{id: 10, status: 2, type: 'movie', media: {status: 2, tmdbId: 44}}]})});
  assert.equal(seeded.length, 0, 'initial tracker baseline emits no notification');
  const linkedChange = { nextState: {10: {requestStatus: 2, mediaStatus: 5, type: 'movie', tmdbId: 44}}, changes: [{id: '10', item: {requestStatus: 2, mediaStatus: 5, tmdbId: 44, type: 'movie'}, text: 'available'}] };
  const availability = await run(nodeCode('jellyseerr-tracker', 'Build push'), { input: [{json: linkedChange}], state: {}, env: {JELLYSEERR_API_KEY: 'test'} });
  assert.equal(availability.length, 0, 'availability transition does not push');
  const newRequest = { ...linkedChange, changes: [{id: '11', isNew: true, item: {requestStatus: 1, mediaStatus: 2, tmdbId: 45, type: 'movie'}, text: 'new request'}], nextState: {11: {requestStatus: 1, mediaStatus: 2}} };
  const push = await run(nodeCode('jellyseerr-tracker', 'Build push'), { input: [{json: newRequest}], state: {} });
  assert.equal(push.length, 1, 'new request produces a push');
  assert.equal(push[0].json.event, true);
  assert.match(push[0].json.title, /Film #45/);
  assert.equal(push[0].json.message, 'Film #45', 'missing media lookup details use a readable id fallback');
  const autoApproved = {...newRequest, changes: [{id: '12', isNew: true, item: {requestStatus: 2, mediaStatus: 2, tmdbId: 46, type: 'movie'}, text: 'new request, approved'}]};
  const autoApprovedPush = await run(nodeCode('jellyseerr-tracker', 'Build push'), {input: [{json: autoApproved}], state: {}});
  assert.equal(autoApprovedPush.length, 1, 'new auto-approved request also produces a push');
  const state = {};
  await run(nodeCode('jellyseerr-tracker', 'Build push'), {input: [{json: {...newRequest, changes: [{id: '11', item: {requestStatus: 2, mediaStatus: 2}, text:'pending'}]}}], state});
  assert.ok(state.requests, 'state commits when there is no push');

  for (const name of ['media-arrivals', 'forgejo-releases', 'inbox-organizer']) assert.equal(workflow(name).active, false, `${name} is disabled`);
})().catch((error) => { console.error(error); process.exitCode = 1; });
