const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const file = process.argv[2] || path.join(__dirname, '../hosts/nixos/inari/services/n8n/workflows/disk-health.json');
const code = JSON.parse(fs.readFileSync(file)).nodes.find(n => n.name === 'Examine drives').parameters.jsCode;
const series = (metric, value) => ({metric: {metric, device: 'nvme0'}, value: [0, String(value)]});
async function run(metrics, fail = false) {
  return vm.runInNewContext(`(async function(){\n${code}\n}).call({helpers})`, {
    $getWorkflowStaticData: () => ({}),
    helpers: {httpRequest: async () => {if (fail) throw Error('offline'); return {data: {result: metrics}};}},
  });
}
(async () => {
  const unavailable = await run([], true);
  const recovered = await run([]);
  assert(recovered.some(a => a.json.fingerprint === unavailable[0].json.fingerprint && a.json.resolved), 'Prometheus recovery closes its prior warning');
  const silent = recovered.find(a => a.json.fingerprint === 'disk-health:no-drive-metrics');
  assert(silent && silent.json.resolved === false && silent.json.severity === 'warning', 'Prometheus answering without smart_status is a warning, not silence');
  const healthy = await run([series('smart_status', 1)]);
  assert(healthy.some(a => a.json.fingerprint === 'disk-health:no-drive-metrics' && a.json.resolved === true), 'a reporting drive resolves the missing-metrics warning');
  const worn = await run([series('smart_status', 1),series('wear_pct', 90),series('wear_per_day', 1)]);
  assert(worn.find(a => a.json.fingerprint.includes('wear-tier')).json.event, 'tier crossing is a one-off event');
  const projection = worn.find(a => a.json.fingerprint.includes('wear-projection'));
  assert.equal(projection.json.resolved, false);
  const replacement = await run([series('smart_status', 1),series('wear_pct', 1),series('wear_per_day', 0)]);
  assert(replacement.some(a => a.json.fingerprint === projection.json.fingerprint && a.json.resolved), 'recovered projection stops daily reminders');
  console.log('disk alerts: Prometheus and wear-projection recoveries passed');
})().catch(error => {console.error(error);process.exitCode=1;});
