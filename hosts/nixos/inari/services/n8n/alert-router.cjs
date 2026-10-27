'use strict';

const fs = require('node:fs/promises');
const http = require('node:http');
const path = require('node:path');

const HOUR = 60 * 60 * 1000;
const DAY = 24 * HOUR;
// After this many failed publishes in a row an entry waits an hour between
// attempts, so one message ntfy keeps rejecting does not retry every minute.
const MAX_ATTEMPTS = 5;
const SPEC = {
  critical: {priority: 5, tag: 'rotating_light', rank: 2},
  warning: {priority: 4, tag: 'warning', rank: 1},
  info: {priority: 3, tag: 'information_source', rank: 0},
};

function createRouter({statePath, env = process.env, httpRequest = defaultPublish, now = () => new Date()} = {}) {
  if (!statePath) throw new TypeError('statePath is required');
  let state = {alerts: Object.create(null)};
  let queue = Promise.resolve();

  const ready = (async () => {
    try {
      const loaded = JSON.parse(await fs.readFile(statePath, 'utf8'));
      state.alerts = Object.assign(Object.create(null), loaded.alerts ?? {});
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
  })();

  async function save(next) {
    const directory = path.dirname(statePath);
    await fs.mkdir(directory, {recursive: true, mode: 0o700});
    const temporary = `${statePath}.${process.pid}.${Math.random().toString(16).slice(2)}.tmp`;
    try {
      await fs.writeFile(temporary, JSON.stringify({alerts: next}), {mode: 0o600, flag: 'wx'});
      await fs.rename(temporary, statePath);
      await fs.chmod(statePath, 0o600);
    } catch (error) {
      await fs.rm(temporary, {force: true}).catch(() => {});
      throw error;
    }
  }

  async function route(alertArray) {
    await ready;
    const alerts = Object.assign(Object.create(null), state.alerts);
    const instant = now();
    const timestamp = instant instanceof Date ? instant.getTime() : Number(instant);
    const hour = Number(new Intl.DateTimeFormat('en-GB', {
      timeZone: 'Europe/Berlin', hour: 'numeric', hour12: false,
    }).format(new Date(timestamp)));
    const quiet = hour >= 22 || hour < 7;

    for (const raw of alertArray) {
      if (!raw || typeof raw !== 'object' || Array.isArray(raw)) throw new Error('Invalid alert');
      const severity = String(raw.severity ?? 'warning').toLowerCase();
      if (!Object.hasOwn(SPEC, severity)) throw new Error('Alert severity must be critical, warning or info');
      const title = String(raw.title ?? '').trim();
      if (!title) throw new Error('Alert needs a title');
      const source = String(raw.source ?? 'unknown');
      const fingerprint = String(raw.fingerprint ?? `${source}:${title}`);
      const previous = alerts[fingerprint];
      const resolved = raw.resolved === true || raw.resolved === 'true';
      if (resolved && !previous) continue;
      if (resolved && !previous.lastSent) {
        delete alerts[fingerprint];
        continue;
      }
      const event = raw.event === true;
      const changedSeverity = previous && SPEC[severity].rank > (SPEC[previous.severity]?.rank ?? -1);
      alerts[fingerprint] = {
        ...previous, severity,
        alert: {source, title, message: String(raw.message ?? ''), severity,
          url: raw.url ? String(raw.url) : null,
          tags: Array.isArray(raw.tags) ? raw.tags.map(String) : [], event, resolved},
        lastSeen: timestamp,
        pending: resolved || !previous?.lastSent || changedSeverity || Boolean(previous.pending),
      };
    }

    // Persist receipts before publishing anything: a failed publish must not
    // lose the alerts that arrived with this call.
    await save(alerts);
    state.alerts = alerts;

    let sent = 0;
    let failed = 0;
    for (const [fingerprint, entry] of Object.entries(alerts)) {
      if (!entry.alert) {
        if (timestamp - (entry.lastSent ?? 0) > 7 * DAY) delete alerts[fingerprint];
        continue;
      }
      const alert = entry.alert;
      const due = entry.pending || (!alert.event && !alert.resolved && timestamp - entry.lastSent >= DAY);
      if (!due) {
        if (alert.event && timestamp - entry.lastSent > 7 * DAY) delete alerts[fingerprint];
        continue;
      }
      if (quiet && (alert.resolved || alert.severity !== 'critical')) continue;
      if (entry.retryAt && timestamp < entry.retryAt) continue;
      const spec = SPEC[alert.severity];
      const prefix = alert.resolved ? '[OK]' : {critical: '[CRIT]', warning: '[WARN]', info: '[INFO]'}[alert.severity];
      const reminder = entry.lastSent && !entry.pending ? 'Still unresolved.\n\n' : '';
      try {
        const response = await httpRequest({
          method: 'POST', url: env.NTFY_URL,
          headers: {Authorization: `Bearer ${env.NTFY_TOKEN}`},
          body: {topic: env.NTFY_TOPIC,
            title: `${prefix} ${alert.source} · ${alert.title}`,
            message: reminder + (alert.message || alert.title),
            priority: alert.resolved ? 3 : spec.priority,
            tags: alert.resolved ? ['white_check_mark'] : [spec.tag, ...alert.tags],
            ...(alert.url ? {click: alert.url} : {})},
          json: true, timeout: 15000,
        });
        if (response?.status >= 400 || response?.ok === false) throw new Error(`Publish failed with status ${response.status}`);
      } catch (error) {
        // One entry ntfy rejects must not hold back the others behind it.
        failed += 1;
        entry.failures = (entry.failures ?? 0) + 1;
        if (entry.failures >= MAX_ATTEMPTS) entry.retryAt = timestamp + HOUR;
        console.error(`alert-router: publishing ${JSON.stringify(fingerprint)} failed (attempt ${entry.failures}${entry.retryAt ? ', deferred one hour' : ''}): ${error?.message ?? error}`);
        continue;
      }
      sent += 1;
      if (alert.resolved) delete alerts[fingerprint];
      else {
        entry.lastSent = timestamp;
        entry.pending = false;
        delete entry.failures;
        delete entry.retryAt;
      }
    }
    await save(alerts);
    return {sent, failed, queued: Object.values(alerts).filter((entry) => entry.pending).length};
  }

  function submit(alertArray) {
    if (!Array.isArray(alertArray)) return Promise.reject(new TypeError('Alerts must be an array'));
    const operation = queue.then(() => route(alertArray));
    queue = operation.catch(() => {});
    return operation;
  }

  return {submit};
}

async function defaultPublish({url, headers, body, timeout}) {
  const response = await fetch(url, {
    method: 'POST', headers: {...headers, 'content-type': 'application/json'},
    body: JSON.stringify(body), signal: AbortSignal.timeout(timeout),
  });
  if (!response.ok) throw new Error('Publish failed');
  return response;
}

function startServer() {
  const statePath = process.env.ALERT_ROUTER_STATE || '/var/lib/n8n-alert-router/state.json';
  const port = Number(process.env.PORT || 8508);
  const router = createRouter({statePath});
  const server = http.createServer(async (request, response) => {
    if (request.method !== 'POST' || request.url !== '/alert') {
      response.writeHead(404).end();
      return;
    }
    let body = '';
    try {
      for await (const chunk of request) {
        body += chunk;
        if (Buffer.byteLength(body) > 64 * 1024) {
          response.writeHead(413).end();
          return;
        }
      }
      const parsed = JSON.parse(body || '[]');
      const alerts = Array.isArray(parsed) ? parsed : [parsed];
      const result = await router.submit(alerts);
      response.writeHead(200, {'content-type': 'application/json'}).end(JSON.stringify(result));
    } catch (error) {
      console.error(`alert-router: request failed: ${error?.message ?? error}`);
      response.writeHead(503, {'content-type': 'application/json'}).end('{"error":"alert routing failed"}');
    }
  });
  server.listen(port, '127.0.0.1');
  const drain = setInterval(() => router.submit([]).catch((error) => console.error(`alert-router: drain failed: ${error?.message ?? error}`)), 60_000);
  drain.unref();
  return {server, drain};
}

if (require.main === module) startServer();
module.exports = {createRouter};
