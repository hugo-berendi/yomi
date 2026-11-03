'use strict';
// Loopback bridge between n8n and Actual. Actual has no REST API, only the
// @actual-app/api library, and n8n Code nodes cannot load it. The library
// downloads the whole budget, keeps global state and needs a native sqlite,
// so each request opens a fresh copy under the runtime directory (tmpfs),
// syncs, and closes it again. Requests are serialised for the same reason.

const crypto = require('node:crypto');
const fs = require('node:fs');
const http = require('node:http');
const path = require('node:path');

const api = require(process.env.ACTUAL_API_MODULE);

function credential(name) {
  const directory = process.env.CREDENTIALS_DIRECTORY;
  if (!directory) return '';
  const file = path.join(directory, name);
  return fs.existsSync(file) ? fs.readFileSync(file, 'utf8').trim() : '';
}

const config = {
  host: process.env.BRIDGE_HOST || '127.0.0.1',
  port: Number(process.env.BRIDGE_PORT),
  serverURL: process.env.ACTUAL_SERVER_URL,
  budgetSyncId: process.env.ACTUAL_BUDGET_SYNC_ID || '',
  dataRoot: process.env.RUNTIME_DIRECTORY || fs.mkdtempSync('/tmp/actual-bridge-'),
  sessionToken: credential('session-token'),
  apiKey: credential('api-key'),
  budgetPassword: credential('budget-password'),
};

class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

let queue = Promise.resolve();
function exclusive(task) {
  const run = queue.then(task, task);
  queue = run.catch(() => {});
  return run;
}

async function chooseBudget() {
  const budgets = (await api.getBudgets()).filter((budget) => budget.groupId);
  if (config.budgetSyncId) {
    if (!budgets.some((budget) => budget.groupId === config.budgetSyncId)) {
      throw new HttpError(500, `Budget ${config.budgetSyncId} is not on the server`);
    }
    return config.budgetSyncId;
  }
  if (budgets.length !== 1) {
    const names = budgets.map((budget) => `${budget.name} (${budget.groupId})`).join(', ');
    throw new HttpError(500, `Expected exactly one budget, found ${budgets.length}: ${names}. Set ACTUAL_BUDGET_SYNC_ID.`);
  }
  return budgets[0].groupId;
}

async function withBudget(task) {
  const dataDir = fs.mkdtempSync(path.join(config.dataRoot, 'budget-'));
  try {
    await api.init({dataDir, serverURL: config.serverURL, sessionToken: config.sessionToken});
    const syncId = await chooseBudget();
    await api.downloadBudget(syncId, config.budgetPassword ? {password: config.budgetPassword} : undefined);
    const result = await task();
    await api.sync();
    return result;
  } finally {
    await api.shutdown().catch(() => {});
    fs.rmSync(dataDir, {recursive: true, force: true});
  }
}

// One account at a time: the library's all-accounts call throws on the first
// failure, which would hide every other account's result.
async function bankSync() {
  const accounts = (await api.getAccounts()).filter((account) => !account.closed);
  const results = [];
  for (const account of accounts) {
    try {
      await api.runBankSync({accountId: account.id});
      results.push({id: account.id, name: account.name, ok: true});
    } catch (error) {
      results.push({id: account.id, name: account.name, ok: false, code: error.code ?? null, error: String(error.message ?? error)});
    }
  }
  return {accounts: results};
}

function isoDate(daysAgo) {
  const date = new Date(Date.now() - daysAgo * 86400000);
  return date.toISOString().slice(0, 10);
}

async function snapshot({days = 180} = {}) {
  const span = Math.min(Math.max(Number(days) || 180, 1), 730);
  const accounts = await api.getAccounts();
  const groups = await api.getCategoryGroups();
  const payees = await api.getPayees();
  const start = isoDate(span);
  const end = isoDate(-1);
  const transactions = [];
  for (const account of accounts) {
    if (account.closed) continue;
    for (const transaction of await api.getTransactions(account.id, start, end)) {
      const rows = transaction.is_parent ? (transaction.subtransactions ?? []) : [transaction];
      for (const row of rows) {
        transactions.push({
          id: row.id,
          account: account.id,
          date: row.date,
          amount: row.amount,
          payee: row.payee ?? null,
          imported_payee: row.imported_payee ?? null,
          notes: row.notes ?? null,
          category: row.category ?? null,
          transfer: Boolean(row.transfer_id),
          starting_balance: Boolean(row.starting_balance_flag),
          child: Boolean(row.is_child),
        });
      }
    }
  }
  return {
    accounts: accounts.map(({id, name, offbudget, closed}) => ({id, name, offbudget, closed})),
    categories: groups.flatMap((group) => (group.categories ?? []).map((category) => ({
      id: category.id, name: category.name, group: group.name, is_income: category.is_income, hidden: category.hidden,
    }))),
    payees: payees.map(({id, name, transfer_acct}) => ({id, name, transfer: Boolean(transfer_acct)})),
    transactions,
  };
}

// Only ever fills an empty category. A transaction categorised by hand
// between the snapshot and this call is left alone.
async function categorize({updates} = {}) {
  if (!Array.isArray(updates)) throw new HttpError(400, 'updates must be an array');
  const known = new Set((await api.getCategories()).map((category) => category.id));
  const applied = [];
  const skipped = [];
  for (const update of updates) {
    const {id, category, note} = update ?? {};
    if (typeof id !== 'string' || !known.has(category)) {
      skipped.push({id, reason: 'unknown transaction or category'});
      continue;
    }
    const {data} = await api.aqlQuery(api.q('transactions').filter({id}).select(['id', 'category', 'notes', 'transfer_id']).options({splits: 'inline'}));
    const current = data?.[0];
    if (!current || current.category || current.transfer_id) {
      skipped.push({id, reason: current ? 'already categorised or transfer' : 'not found'});
      continue;
    }
    const fields = {category};
    if (typeof note === 'string' && note && !(current.notes ?? '').includes(note)) {
      fields.notes = current.notes ? `${current.notes} ${note}` : note;
    }
    await api.updateTransaction(id, fields);
    applied.push(id);
  }
  return {applied, skipped};
}

const routes = {'/bank-sync': bankSync, '/snapshot': snapshot, '/categorize': categorize};

function authorised(request) {
  const header = request.headers.authorization ?? '';
  const given = Buffer.from(header.startsWith('Bearer ') ? header.slice(7) : '');
  const expected = Buffer.from(config.apiKey);
  return expected.length > 0 && given.length === expected.length && crypto.timingSafeEqual(given, expected);
}

async function readJson(request) {
  const chunks = [];
  let size = 0;
  for await (const chunk of request) {
    size += chunk.length;
    if (size > 1 << 20) throw new HttpError(413, 'Body too large');
    chunks.push(chunk);
  }
  if (!size) return {};
  try {
    return JSON.parse(Buffer.concat(chunks).toString('utf8'));
  } catch {
    throw new HttpError(400, 'Body is not JSON');
  }
}

const server = http.createServer(async (request, response) => {
  const send = (status, body) => {
    response.writeHead(status, {'Content-Type': 'application/json'});
    response.end(JSON.stringify(body));
  };
  try {
    if (request.method === 'GET' && request.url === '/health') return send(200, {ok: true});
    if (!authorised(request)) throw new HttpError(401, 'Unauthorised');
    const route = routes[request.url];
    if (request.method !== 'POST' || !route) throw new HttpError(404, 'Not found');
    const body = await readJson(request);
    const result = await exclusive(() => withBudget(() => route(body)));
    send(200, result);
  } catch (error) {
    const status = error.status ?? 500;
    if (status >= 500) console.error(error);
    send(status, {error: String(error.message ?? error), code: error.code ?? null});
  }
});

if (!config.sessionToken || !config.apiKey || !config.serverURL || !config.port) {
  console.error('Missing session token, API key, server URL or port');
  process.exit(1);
}
server.requestTimeout = 15 * 60 * 1000;
server.listen(config.port, config.host, () => console.log(`actual-bridge listening on ${config.host}:${config.port}`));
