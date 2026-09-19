const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');

const workflow = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const code = workflow.nodes.find(n => n.parameters.jsCode).parameters.jsCode;
const now = Date.now() / 1000;
const metric = (name, key, value) => ({metric: {[key]: name}, value: [now, String(value)]});

async function check(name, ages, failed, expected) {
  const context = vm.createContext({helpers: {httpRequest: async ({qs}) => {
    const q = qs.query;
    const result = q.startsWith('yomi_restic_')
      ? ages.map(([backup, hours]) => metric(backup, 'backup', now - hours * 3600))
      : q.startsWith('node_systemd_')
        ? failed.map(backup => metric(`restic-backups-${backup}.service`, 'name', 1))
        : q === 'zfs_pool_health' ? [metric('raid5pool', 'pool', 0)]
        : q === 'zfs_pool_size_bytes' ? [metric('raid5pool', 'pool', 1000)]
        : q === 'zfs_pool_free_bytes' ? [metric('raid5pool', 'pool', 800)]
        : q.startsWith('zfs_dataset_used') ? [metric('raid5pool/backups', 'name', 100)]
        : [];
    return {data: {result}};
  }}});
  // Match n8n's VM instead of giving the workflow Node's process globals.
  const result = await vm.runInContext(`(async function(){${code}\n}).call({helpers})`, context);
  assert(result[0].json.subject.includes(expected), `${name}: ${result[0].json.subject}`);
  if (name === 'missing') assert(result[0].json.html.includes('NO SUCCESS'));
  if (name === 'failed') assert(result[0].json.html.includes('FAILED'));
  if (name === 'healthy' && process.argv[3]) fs.writeFileSync(process.argv[3], result[0].json.html);
  console.log(`${name}: passed`);
}

(async () => {
  await check('healthy', [['data', 1], ['state', 2], ['offsite', 3]], [], '[ OK ]');
  await check('missing', [], [], '[CRIT]');
  await check('stale', [['data', 31], ['state', 2], ['offsite', 3]], [], '[WARN]');
  await check('failed', [['data', 1], ['state', 2], ['offsite', 3]], ['offsite'], '[CRIT]');
  await check('very stale', [['data', 51], ['state', 2], ['offsite', 3]], [], '[CRIT]');
})().catch(error => {console.error(error); process.exitCode = 1;});
