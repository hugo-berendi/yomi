const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const file = process.argv[2] || path.join(__dirname, '../hosts/nixos/inari/services/n8n/workflows/paperless-dates.json');
const workflow = JSON.parse(fs.readFileSync(file));
const code = workflow.nodes.find(n => n.name === 'Prepare reminders').parameters.jsCode;

const ymd = offset => {
  const d = new Date();
  d.setHours(12, 0, 0, 0);
  d.setDate(d.getDate() + offset);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
};
async function run(daysAhead, sent = {}) {
  const date = ymd(daysAhead);
  const state = {sent};
  const httpRequest = async ({url}) => {
    if (url.includes('/api/custom_fields/?')) return {results: [{id: 9, name: 'Reminder date'}]};
    return {results: [{id: 1, title: 'Tax', custom_fields: [{field: 9, value: date}]}], next: null};
  };
  const out = await vm.runInNewContext(`(async function(){\n${code}\n}).call({helpers})`, {
    $env: {PAPERLESS_API_TOKEN: 'x'},
    $getWorkflowStaticData: () => state,
    helpers: {httpRequest},
    Date,
  });
  return {out, date};
}

(async () => {
  const missed = await run(5);
  assert.equal(missed.out.length, 1, 'a missed 7-day rung is caught up at 5 days');
  assert.equal(missed.out[0].json.sentKeys.join(), `1:${missed.date}:7`);
  assert.equal(missed.out[0].json.unsent[0].days, 5, 'the real remaining days are shown');
  const already = await run(5, {[`1:${ymd(5)}:7`]: 1});
  assert.equal(already.out.length, 0, 'an already-sent rung is not resent');
  assert.equal((await run(7)).out[0].json.sentKeys[0], `1:${ymd(7)}:7`, 'exact rung day keeps its key format');
  assert.equal((await run(0)).out.length, 1, 'due today is sent');
  assert.equal((await run(-2)).out.length, 0, 'overdue documents are not reminded');
  assert.equal((await run(45)).out.length, 0, 'nothing is sent before the first rung');
  const targets = workflow.connections['Prepare reminders'].main[0].map(c => c.node);
  assert.deepEqual(targets, ['Build push', 'Send reminders'], 'push runs before the mail so a mail failure cannot suppress it');
  console.log('paperless reminders: catch-up, dedupe and push-first order passed');
})().catch(error => {console.error(error);process.exitCode=1;});
