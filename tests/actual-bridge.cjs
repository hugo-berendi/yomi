'use strict';
// End-to-end check of the n8n -> Actual bridge against the pinned server and
// API bundle. Everything is disposable and synthetic: a fresh actual-server
// with a throwaway password on loopback, a budget seeded through
// @actual-app/api, and the real bridge.cjs under the same Node, NODE_PATH and
// API module its systemd unit uses. No bank, OpenID or other outside service.
//
// Inputs (environment):
//   ACTUAL_SERVER_EXE   actual-server wrapper from services.actual.package
//   BRIDGE_EXEC         the bridge unit's ExecStart ("<node> <bridge.cjs>")
//   ACTUAL_API_MODULE, NODE_PATH   copied from the bridge unit's environment

const assert = require('node:assert/strict');
const {spawn} = require('node:child_process');
const fs = require('node:fs');
const net = require('node:net');
const os = require('node:os');
const path = require('node:path');

const api = require(process.env.ACTUAL_API_MODULE);

const root = fs.mkdtempSync(path.join(os.tmpdir(), 'actual-bridge-test-'));
const children = [];
let stopping = false;
const PASSWORD = 'synthetic-test-password';
const API_KEY = 'synthetic-bridge-key';

function log(message) {
  console.log(`[actual-bridge-test] ${message}`);
}

function freePort() {
  return new Promise((resolve, reject) => {
    const server = net.createServer();
    server.unref();
    server.on('error', reject);
    server.listen(0, '127.0.0.1', () => {
      const {port} = server.address();
      server.close(() => resolve(port));
    });
  });
}

function start(name, command, args, env) {
  const child = spawn(command, args, {env, cwd: root, stdio: ['ignore', 'pipe', 'pipe']});
  const prefix = (stream) => stream.on('data', (chunk) => {
    for (const line of chunk.toString().split('\n')) if (line) console.log(`  ${name}: ${line}`);
  });
  prefix(child.stdout);
  prefix(child.stderr);
  child.on('exit', (code, signal) => {
    child.exited = true;
    if (!stopping) log(`${name} exited early (code ${code}, signal ${signal})`);
  });
  children.push(child);
  return child;
}

async function waitFor(url, child, name) {
  const deadline = Date.now() + 60_000;
  while (Date.now() < deadline) {
    if (child.exited) throw new Error(`${name} exited before becoming ready`);
    try {
      const response = await fetch(url);
      if (response.ok) return;
    } catch {}
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  throw new Error(`${name} not ready at ${url} within 60 s`);
}

async function json(url, {method = 'POST', body, headers = {}, raw} = {}) {
  const response = await fetch(url, {
    method,
    headers: {'Content-Type': 'application/json', ...headers},
    body: raw ?? (body === undefined ? undefined : JSON.stringify(body)),
  });
  const text = await response.text();
  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch {
    parsed = text;
  }
  return {status: response.status, body: parsed};
}

function daysAgo(days) {
  return new Date(Date.now() - days * 86400000).toISOString().slice(0, 10);
}

async function main() {
  const serverPort = await freePort();
  const bridgePort = await freePort();
  const serverURL = `http://127.0.0.1:${serverPort}`;
  const bridgeURL = `http://127.0.0.1:${bridgePort}`;
  const home = path.join(root, 'home');
  fs.mkdirSync(home);
  const baseEnv = {PATH: process.env.PATH ?? '', HOME: home, TZ: 'UTC'};

  // {{{ Disposable actual-server
  const serverData = path.join(root, 'server');
  fs.mkdirSync(serverData);
  const server = start('actual-server', process.env.ACTUAL_SERVER_EXE, [], {
    ...baseEnv,
    ACTUAL_DATA_DIR: serverData,
    ACTUAL_HOSTNAME: '127.0.0.1',
    ACTUAL_PORT: String(serverPort),
    ACTUAL_LOGIN_METHOD: 'password',
    ACTUAL_ALLOWED_LOGIN_METHODS: 'password',
    ACTUAL_TRUSTED_PROXIES: '127.0.0.1/32',
  });
  await waitFor(`${serverURL}/health`, server, 'actual-server');
  const info = await json(`${serverURL}/info`, {method: 'GET'});
  log(`server ${info.body?.build?.version}`);

  const boot = await json(`${serverURL}/account/bootstrap`, {body: {password: PASSWORD}});
  assert.equal(boot.status, 200, `bootstrap failed: ${JSON.stringify(boot.body)}`);
  const login = await json(`${serverURL}/account/login`, {body: {loginMethod: 'password', password: PASSWORD}});
  const token = login.body?.data?.token;
  assert.ok(token, `login returned no token: ${JSON.stringify(login.body)}`);
  // }}}

  // {{{ Seed a synthetic budget through the pinned API
  const ids = {};
  const seedDir = path.join(root, 'seed');
  fs.mkdirSync(seedDir);
  await api.init({dataDir: seedDir, serverURL, sessionToken: token});
  await api.runImport('Synthetic Bridge Test', async () => {
    const group = await api.createCategoryGroup({name: 'Test Spending'});
    ids.groceries = await api.createCategory({name: 'Groceries', group_id: group});
    ids.transport = await api.createCategory({name: 'Transport', group_id: group});
    ids.checking = await api.createAccount({name: 'Test Checking', offbudget: false});
    ids.closed = await api.createAccount({name: 'Test Closed', offbudget: false, closed: true});
    await api.addTransactions(ids.checking, [
      {date: daysAgo(3), amount: -1234, payee_name: 'Synthetic Market', imported_id: 'uncat', notes: 'bank text'},
      {date: daysAgo(4), amount: -500, payee_name: 'Synthetic Rail', imported_id: 'cat', category: ids.transport},
      {date: daysAgo(5), amount: -2000, payee_name: 'Synthetic Split', imported_id: 'split', subtransactions: [
        {amount: -1500, category: ids.groceries},
        {amount: -500},
      ]},
      {date: daysAgo(90), amount: -999, payee_name: 'Synthetic Old', imported_id: 'old'},
    ]);
  });
  const budgets = (await api.getBudgets()).filter((budget) => budget.state === 'remote' && budget.groupId);
  assert.equal(budgets.length, 1, `seeded budget did not reach the server: ${JSON.stringify(budgets)}`);
  const syncId = budgets[0].groupId;
  const seeded = await api.getTransactions(ids.checking, daysAgo(400), daysAgo(-1));
  const byImported = Object.fromEntries(seeded.map((transaction) => [transaction.imported_id, transaction]));
  for (const key of ['uncat', 'cat', 'split', 'old']) assert.ok(byImported[key], `seed lost ${key}`);
  await api.shutdown();
  log(`seeded budget ${syncId}`);
  // }}}

  // {{{ The real bridge, launched as its unit launches it
  const credentials = path.join(root, 'credentials');
  fs.mkdirSync(credentials, {mode: 0o700});
  fs.writeFileSync(path.join(credentials, 'session-token'), `${token}\n`);
  fs.writeFileSync(path.join(credentials, 'api-key'), `${API_KEY}\n`);
  const runtime = path.join(root, 'runtime');
  fs.mkdirSync(runtime, {mode: 0o700});
  const [node, ...bridgeArgs] = process.env.BRIDGE_EXEC.split(' ');
  const bridge = start('actual-bridge', node, bridgeArgs, {
    ...baseEnv,
    ACTUAL_API_MODULE: process.env.ACTUAL_API_MODULE,
    NODE_PATH: process.env.NODE_PATH,
    NODE_ENV: 'production',
    ACTUAL_SERVER_URL: serverURL,
    BRIDGE_PORT: String(bridgePort),
    CREDENTIALS_DIRECTORY: credentials,
    RUNTIME_DIRECTORY: runtime,
  });
  await waitFor(`${bridgeURL}/health`, bridge, 'actual-bridge');
  const auth = {Authorization: `Bearer ${API_KEY}`};
  // }}}

  // {{{ HTTP contract
  assert.equal((await json(`${bridgeURL}/snapshot`, {body: {}})).status, 401, 'no key must be refused');
  assert.equal((await json(`${bridgeURL}/snapshot`, {body: {}, headers: {Authorization: 'Bearer wrong-key-of-same-len'}})).status, 401, 'wrong key must be refused');
  assert.equal((await json(`${bridgeURL}/nope`, {body: {}, headers: auth})).status, 404, 'unknown route');
  assert.equal((await json(`${bridgeURL}/snapshot`, {method: 'GET', headers: auth})).status, 404, 'GET on a POST route');
  assert.equal((await json(`${bridgeURL}/snapshot`, {raw: '{not json', headers: auth})).status, 400, 'malformed JSON');
  assert.equal((await json(`${bridgeURL}/categorize`, {body: {updates: 'x'}, headers: auth})).status, 400, 'updates must be an array');
  log('HTTP contract ok');
  // }}}

  // {{{ Read: snapshot
  const first = await json(`${bridgeURL}/snapshot`, {body: {days: 30}, headers: auth});
  assert.equal(first.status, 200, JSON.stringify(first.body));
  const snap = first.body;
  const account = snap.accounts.find((entry) => entry.id === ids.checking);
  assert.ok(account && account.closed === false, 'open account in snapshot');
  assert.ok(snap.accounts.some((entry) => entry.id === ids.closed && entry.closed), 'closed account listed as closed');
  const groceries = snap.categories.find((entry) => entry.id === ids.groceries);
  assert.equal(groceries?.group, 'Test Spending');
  assert.ok(snap.payees.some((payee) => payee.name === 'Synthetic Market'), 'payees listed');
  const rows = Object.fromEntries(snap.transactions.map((row) => [row.id, row]));
  assert.ok(rows[byImported.uncat.id], 'uncategorised transaction in window');
  assert.equal(rows[byImported.uncat.id].category, null);
  assert.equal(rows[byImported.uncat.id].amount, -1234);
  assert.equal(rows[byImported.cat.id]?.category, ids.transport);
  assert.ok(!rows[byImported.old.id], '90-day-old transaction outside a 30-day window');
  assert.ok(!rows[byImported.split.id], 'split parent replaced by its children');
  const splitRows = snap.transactions.filter((row) => row.child);
  assert.equal(splitRows.length, 2, `split children: ${JSON.stringify(splitRows)}`);
  assert.deepEqual(splitRows.map((row) => row.amount).sort((a, b) => a - b), [-1500, -500]);
  const uncategorisedChild = splitRows.find((row) => row.category === null);
  assert.ok(uncategorisedChild, 'one split child is uncategorised');
  assert.ok(snap.transactions.every((row) => row.account === ids.checking), 'closed accounts skipped');
  const wide = await json(`${bridgeURL}/snapshot`, {body: {days: 120}, headers: auth});
  assert.ok(wide.body.transactions.some((row) => row.id === byImported.old.id), 'wider window includes old transaction');
  log('snapshot ok');
  // }}}

  // {{{ Write: categorize, fill-empty-only
  const updates = [
    {id: byImported.uncat.id, category: ids.groceries, note: '#auto'},
    {id: byImported.cat.id, category: ids.groceries},
    {id: byImported.old.id, category: 'not-a-category'},
    {id: 'no-such-transaction', category: ids.groceries},
  ];
  const written = await json(`${bridgeURL}/categorize`, {body: {updates}, headers: auth});
  assert.equal(written.status, 200, JSON.stringify(written.body));
  assert.deepEqual(written.body.applied, [byImported.uncat.id]);
  assert.deepEqual(written.body.skipped.map((entry) => [entry.id, entry.reason]), [
    [byImported.cat.id, 'already categorised or transfer'],
    [byImported.old.id, 'unknown transaction or category'],
    ['no-such-transaction', 'not found'],
  ]);
  const again = await json(`${bridgeURL}/categorize`, {body: {updates: updates.slice(0, 1)}, headers: auth});
  assert.deepEqual(again.body.applied, [], 'second run must not rewrite');
  log('categorize ok');
  // }}}

  // {{{ The write reached the server, seen by an independent client
  const verifyDir = path.join(root, 'verify');
  fs.mkdirSync(verifyDir);
  await api.init({dataDir: verifyDir, serverURL, sessionToken: token});
  await api.downloadBudget(syncId);
  const after = await api.getTransactions(ids.checking, daysAgo(400), daysAgo(-1));
  const updated = after.find((transaction) => transaction.id === byImported.uncat.id);
  assert.equal(updated.category, ids.groceries, 'category persisted on server');
  assert.equal(updated.notes, 'bank text #auto', 'note appended once');
  assert.equal(after.find((transaction) => transaction.id === byImported.cat.id).category, ids.transport, 'categorised transaction untouched');
  await api.shutdown();
  log('server state ok');
  // }}}

  // {{{ Bank sync without linked accounts, and request serialisation
  const [sync, parallelA, parallelB] = await Promise.all([
    json(`${bridgeURL}/bank-sync`, {body: {}, headers: auth}),
    json(`${bridgeURL}/snapshot`, {body: {days: 30}, headers: auth}),
    json(`${bridgeURL}/snapshot`, {body: {days: 30}, headers: auth}),
  ]);
  assert.equal(sync.status, 200, JSON.stringify(sync.body));
  assert.deepEqual(sync.body.accounts, [{id: ids.checking, name: 'Test Checking', ok: true}]);
  assert.equal(parallelA.status, 200);
  assert.equal(parallelB.status, 200);
  assert.deepEqual(parallelA.body, parallelB.body, 'concurrent snapshots agree');
  // Each request downloads into its own directory and removes it again.
  assert.deepEqual(fs.readdirSync(runtime), [], 'runtime directory left clean');
  log('bank-sync and serialisation ok');
  // }}}
}

async function stop() {
  stopping = true;
  for (const child of children) if (!child.exited) child.kill('SIGTERM');
  await new Promise((resolve) => setTimeout(resolve, 200));
  fs.rmSync(root, {recursive: true, force: true});
}

const watchdog = setTimeout(() => {
  console.error('[actual-bridge-test] timed out after 5 minutes');
  for (const child of children) child.kill('SIGKILL');
  process.exit(1);
}, 5 * 60_000);

main().then(
  async () => {
    clearTimeout(watchdog);
    await stop();
    log('all checks passed');
    process.exit(0);
  },
  async (error) => {
    clearTimeout(watchdog);
    console.error(error);
    await stop();
    process.exit(1);
  },
);
