const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const workflowPath = process.argv[2] ?? 'hosts/nixos/inari/services/n8n/workflows/webuntis-radicale.json';
const workflow = JSON.parse(fs.readFileSync(workflowPath, 'utf8'));
const node = (name) => workflow.nodes.find((candidate) => candidate.name === name);
const writer = node('Termin in Radicale schreiben');
const deleter = node('Termin aus Radicale löschen');
const committer = node('Sync-Status festschreiben');
assert.ok(writer && deleter && committer, 'expected WebUntis write nodes');

const responseOptions = (candidate) => candidate.parameters.options?.response?.response ?? {};
assert.equal(responseOptions(writer).fullResponse, true, 'PUT must expose the HTTP status');
assert.equal(responseOptions(writer).neverError, undefined, 'PUT errors must stop the workflow');
assert.equal(responseOptions(deleter).fullResponse, true, 'DELETE must expose the HTTP status');
assert.equal(responseOptions(deleter).neverError, true, 'DELETE 404 must reach the commit node');

const code = committer.parameters.jsCode;
const prepareNode = 'Persönliche Termine vorbereiten';
const snapshot = (value) => JSON.parse(JSON.stringify(value));
const makeOperation = (method, href, extra = {}) => ({
  method,
  href,
  body: method === 'PUT' ? `SUMMARY:${href}\nDTSTART:20261001T1200` : '',
  summary: {changes: 1},
  nextState: {[href]: {hash: `hash:${href}`, date: '2026-10-01'}},
  ...extra,
});

function executeCommit(operations, statuses, initialState = {}) {
  const state = {hashByHref: structuredClone(initialState)};
  const input = statuses.map((statusCode) => ({json: {statusCode, body: '', headers: {}}}));
  const linked = {
    itemMatching(index) {
      return {json: operations[index]};
    },
  };
  const context = vm.createContext({
    $input: {all: () => input},
    $getWorkflowStaticData: () => state,
    $: (name) => {
      assert.equal(name, prepareNode);
      return linked;
    },
  });
  const script = new vm.Script(`(function () {\n${code}\n})()`, {filename: 'Sync-Status festschreiben.js'});
  let output;
  try {
    output = script.runInContext(context);
  } catch (error) {
    error.syntheticState = state;
    throw error;
  }
  return {output, state};
}

function captureError(run, pattern) {
  try {
    run();
  } catch (error) {
    assert.match(error.message, pattern);
    return error;
  }
  assert.fail('expected the commit node to reject the response');
}

const previous = {old: {hash: 'old-hash', date: '2026-09-01'}};

// A not-found delete is already in the requested end state and may be committed.
{
  const result = executeCommit([makeOperation('DELETE', 'old')], [404], previous);
  assert.equal(result.state.hashByHref.old, undefined);
  assert.equal(result.output[0].json.operations, 1);
}

// Auth, permission, and server errors must leave the whole state untouched.
for (const status of [401, 403, 500]) {
  const error = captureError(
    () => executeCommit([makeOperation('DELETE', 'old')], [status], previous),
    /HTTP|status|DELETE/i,
  );
  assert.deepEqual(snapshot(error.syntheticState.hashByHref), previous);
}

// Validate the whole batch before recording even a successful sibling.
{
  const error = captureError(
    () => executeCommit([makeOperation('PUT', 'new'), makeOperation('DELETE', 'old')], [204, 500], previous),
    /HTTP|status|DELETE/i,
  );
  assert.deepEqual(snapshot(error.syntheticState.hashByHref), previous);
}

// Losing paired-item data is fatal rather than an acknowledgement.
{
  const error = captureError(() => executeCommit([null], [204], previous), /linked operation/i);
  assert.deepEqual(snapshot(error.syntheticState.hashByHref), previous);
}

// Both successful PUT response codes acknowledge only their own href.
for (const status of [201, 204]) {
  const result = executeCommit([makeOperation('PUT', 'new')], [status], previous);
  assert.deepEqual(snapshot(result.state.hashByHref), {
    ...previous,
    new: {hash: 'hash:new', date: '2026-10-01'},
  });
}

// A failed PUT is not recorded, so a retry remains possible.
{
  const operation = makeOperation('PUT', 'new');
  const error = captureError(() => executeCommit([operation], [500], previous), /HTTP|status|PUT/i);
  assert.deepEqual(snapshot(error.syntheticState.hashByHref), previous);
  const retry = executeCommit([operation], [201], previous);
  assert.equal(retry.state.hashByHref.new.hash, 'hash:new');
}

// A PUT and DELETE in distinct branches update only their acknowledged hrefs.
{
  const result = executeCommit(
    [makeOperation('PUT', 'new'), makeOperation('DELETE', 'old')],
    [204, 404],
    previous,
  );
  assert.deepEqual(snapshot(result.state.hashByHref), {new: {hash: 'hash:new', date: '2026-10-01'}});
}

// Separate branches commit only their own href, even when each operation
// carries the same complete planned snapshot.
{
  const planned = {new: {hash: 'hash:new', date: '2026-10-01'}};
  const put = executeCommit([makeOperation('PUT', 'new', {nextState: planned})], [204], previous);
  assert.deepEqual(snapshot(put.state.hashByHref), {
    ...previous,
    new: {hash: 'hash:new', date: '2026-10-01'},
  });

  const deletion = executeCommit(
    [makeOperation('DELETE', 'old', {nextState: planned})],
    [404],
    put.state.hashByHref,
  );
  assert.deepEqual(snapshot(deletion.state.hashByHref), planned);
}

// Repeating an acknowledged 404 stays idempotent.
{
  const once = executeCommit([makeOperation('DELETE', 'old')], [404], previous);
  const twice = executeCommit([makeOperation('DELETE', 'old')], [404], once.state.hashByHref);
  assert.equal(twice.state.hashByHref.old, undefined);
}

console.log('WebUntis Radicale write-response checks passed');
