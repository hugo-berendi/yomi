'use strict';

// One local process owns every notification decision on inari. Producers
// (Grafana, Gatus via n8n, n8n workflows, the watchdog) post loosely shaped
// alerts; this normalizes them, decides per target whether to deliver, and
// keeps a delivery ledger in one state file that survives restarts. ntfy is
// the only target and is handled inside the request.

const crypto = require('node:crypto');
const fs = require('node:fs/promises');
const http = require('node:http');
const path = require('node:path');

const MINUTE = 60 * 1000;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;
// After this many failed publishes in a row an entry waits an hour between
// attempts, so one message ntfy keeps rejecting does not retry every minute.
const MAX_ATTEMPTS = 5;
const SPEC = {
  critical: {priority: 5, tag: 'rotating_light', rank: 2, prefix: '[CRIT]'},
  warning: {priority: 4, tag: 'warning', rank: 1, prefix: '[WARN]'},
  info: {priority: 3, tag: 'information_source', rank: 0, prefix: '[INFO]'},
};

const rank = (severity) => SPEC[severity]?.rank ?? -1;

function berlinHour(timestamp) {
  return Number(new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Europe/Berlin', hour: 'numeric', hour12: false,
  }).format(new Date(timestamp)));
}
const isQuiet = (timestamp) => {
  const hour = berlinHour(timestamp);
  return hour >= 22 || hour < 7;
};
const berlinTime = (timestamp) => new Intl.DateTimeFormat('de-DE', {
  timeZone: 'Europe/Berlin', day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit',
}).format(new Date(timestamp));

// {{{ Normalization
function clean(value, limit) {
  // eslint-disable-next-line no-control-regex
  return String(value ?? '').replace(/[\u0000-\u0008\u000b-\u001f\u007f]/g, '').trim().slice(0, limit);
}
const NAME = /^[A-Za-z0-9][A-Za-z0-9._@-]{0,79}$/;
const name = (value) => {
  const text = clean(value, 80).toLowerCase();
  return NAME.test(text) ? text : '';
};

// Producers that predate host/service still name the affected thing in their
// fingerprints. Deriving it keeps their existing fingerprints, and with them
// their suppression state, intact.
function deriveService(fingerprint, source) {
  const service = /^service:([^:]+)$/.exec(fingerprint);
  if (service) return name(service[1]);
  if (/^(workflow|monitor):/.test(fingerprint)) return 'n8n';
  return name(source) || 'unknown';
}

function parseTime(value, fallback) {
  if (value === undefined || value === null || value === '') return fallback;
  const parsed = typeof value === 'number' ? value * (value < 1e12 ? 1000 : 1) : Date.parse(String(value));
  // A producer clock far in the future would corrupt the "Since" line.
  if (!Number.isFinite(parsed) || parsed <= 0 || parsed > fallback + 5 * MINUTE) return fallback;
  return parsed;
}

function normalize(raw, received) {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) throw new Error('Invalid alert');
  const severity = String(raw.severity ?? 'warning').toLowerCase();
  if (!Object.hasOwn(SPEC, severity)) throw new Error('Alert severity must be critical, warning or info');
  const title = clean(raw.title, 200);
  if (!title) throw new Error('Alert needs a title');
  const source = clean(raw.source ?? 'unknown', 80) || 'unknown';
  const host = name(raw.host) || 'inari';
  const explicitService = name(raw.service);
  const fingerprint = clean(raw.fingerprint, 300)
    || `${host}:${explicitService || name(source) || 'unknown'}:${title}`;
  const service = explicitService || deriveService(fingerprint, source);
  const status = raw.status === 'resolved' || raw.resolved === true || raw.resolved === 'true'
    ? 'resolved' : 'firing';
  const kind = raw.kind === 'event' || raw.event === true || raw.event === 'true' ? 'event' : 'state';
  const labels = Object.create(null);
  if (raw.labels && typeof raw.labels === 'object' && !Array.isArray(raw.labels)) {
    for (const [key, value] of Object.entries(raw.labels).slice(0, 16)) {
      const label = name(key);
      if (label && value !== null && typeof value !== 'object') labels[label] = clean(value, 200);
    }
  }
  return {
    host, service, explicitService: Boolean(explicitService), fingerprint, severity, status, kind,
    occurredAt: parseTime(raw.occurredAt ?? raw.startsAt ?? raw.timestamp, received),
    source, title,
    message: clean(raw.summary ?? raw.message, 2000),
    url: raw.url ? clean(raw.url, 500) : null,
    tags: Array.isArray(raw.tags) ? raw.tags.slice(0, 8).map((tag) => clean(tag, 40)).filter(Boolean) : [],
    labels,
  };
}
// }}}

// {{{ State
const emptyNtfy = () => ({pending: false, lastSent: null, failures: 0, retryAt: null});

// Version 1 kept one flat entry per fingerprint with ntfy fields at the top;
// carry its suppression state over. Version 2 state written while the removed
// Hermes triage target existed still carries its ledger, which is dropped.
function migrate(loaded) {
  if (loaded?.version === 2) {
    const alerts = Object.create(null);
    for (const [fingerprint, entry] of Object.entries(loaded.alerts ?? {})) {
      const {hermes: _hermes, ...kept} = entry;
      alerts[fingerprint] = kept;
    }
    const {hermes: _target, ...targets} = loaded.targets ?? {};
    return {alerts, targets};
  }
  const alerts = Object.create(null);
  for (const [fingerprint, old] of Object.entries(loaded?.alerts ?? {})) {
    if (!old?.alert) continue;
    const seen = old.lastSeen ?? old.lastSent ?? Date.now();
    const alert = normalize({...old.alert, fingerprint, resolved: old.alert.resolved, event: old.alert.event}, seen);
    alerts[fingerprint] = {
      alert, severity: old.severity ?? alert.severity,
      firstSeen: old.lastSent ?? seen, lastSeen: seen, lastChange: seen,
      ntfy: {pending: Boolean(old.pending), lastSent: old.lastSent ?? null,
        failures: old.failures ?? 0, retryAt: old.retryAt ?? null},
    };
  }
  return {alerts, targets: {}};
}
// }}}

function createRouter({
  statePath, env = process.env, httpRequest = defaultPublish, now = () => new Date(),
} = {}) {
  if (!statePath) throw new TypeError('statePath is required');
  let state = migrate(null);
  let queue = Promise.resolve();

  const clock = () => {
    const instant = now();
    return instant instanceof Date ? instant.getTime() : Number(instant);
  };

  const ready = (async () => {
    try {
      state = migrate(JSON.parse(await fs.readFile(statePath, 'utf8')));
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
  })();

  async function save() {
    const directory = path.dirname(statePath);
    await fs.mkdir(directory, {recursive: true, mode: 0o700});
    const temporary = `${statePath}.${process.pid}.${crypto.randomBytes(6).toString('hex')}.tmp`;
    try {
      await fs.writeFile(temporary, JSON.stringify({version: 2, ...state}), {mode: 0o600, flag: 'wx'});
      await fs.rename(temporary, statePath);
      await fs.chmod(statePath, 0o600);
    } catch (error) {
      await fs.rm(temporary, {force: true}).catch(() => {});
      throw error;
    }
  }

  function serialized(operation) {
    const run = queue.then(async () => {
      await ready;
      return operation();
    });
    queue = run.catch(() => {});
    return run;
  }

  const targetStatus = (name) => (state.targets[name] ??= {});
  function recordTarget(name, timestamp, error) {
    const status = targetStatus(name);
    if (error) Object.assign(status, {lastErrorAt: timestamp, lastError: clean(error, 300)});
    else Object.assign(status, {lastSuccessAt: timestamp});
  }

  // {{{ Receive
  function absorber(alerts, fingerprint, alert) {
    // Gatus, Grafana and the watchdog can all notice the same outage. Only the
    // first to be pushed pages; later ones from other producers for the same
    // host and service ride along silently unless they are more severe.
    if (alert.kind !== 'state' || !alert.explicitService) return null;
    for (const [other, entry] of Object.entries(alerts)) {
      if (other === fingerprint || entry.alert.status !== 'firing' || entry.ntfy.absorbedBy) continue;
      if (entry.alert.host !== alert.host || entry.alert.service !== alert.service) continue;
      if (!entry.alert.explicitService || entry.alert.source === alert.source) continue;
      if (!(entry.ntfy.lastSent || entry.ntfy.pending) || rank(entry.alert.severity) < rank(alert.severity)) continue;
      return other;
    }
    return null;
  }

  function receive(alerts, raw, timestamp) {
    const alert = normalize(raw, timestamp);
    const fingerprint = alert.fingerprint;
    const previous = alerts[fingerprint];

    if (alert.status === 'resolved') {
      if (!previous || previous.alert.status === 'resolved') {
        if (previous) previous.lastSeen = timestamp;
        return;
      }
      const pushed = Boolean(previous.ntfy.lastSent);
      if (!pushed) {
        delete alerts[fingerprint];
        return;
      }
      alerts[fingerprint] = {
        ...previous,
        alert: {...alert, title: previous.alert.title, severity: previous.alert.severity},
        lastSeen: timestamp, lastChange: timestamp, resolvedAt: alert.occurredAt,
        ntfy: {...previous.ntfy, pending: true, failures: 0, retryAt: null},
      };
      return;
    }

    const isNew = !previous;
    // Firing again before the all-clear went out: nothing new to say.
    const reopened = previous?.alert.status === 'resolved';
    const escalated = Boolean(previous) && rank(alert.severity) > rank(previous.severity);
    const ntfy = previous ? {...previous.ntfy} : emptyNtfy();
    if (reopened) {
      ntfy.pending = escalated;
    } else {
      ntfy.pending = !ntfy.lastSent || escalated || Boolean(ntfy.pending);
    }
    if (isNew) {
      const by = absorber(alerts, fingerprint, alert);
      if (by) {
        ntfy.pending = false;
        ntfy.absorbedBy = by;
      }
    }
    if (ntfy.absorbedBy) {
      const by = alerts[ntfy.absorbedBy];
      // Still covered by an incident that already paged at least this loudly.
      if (by?.alert.status === 'firing' && rank(by.alert.severity) >= rank(alert.severity)) ntfy.pending = false;
      else delete ntfy.absorbedBy;
    }
    alerts[fingerprint] = {
      alert, severity: alert.severity,
      firstSeen: previous && !reopened ? previous.firstSeen : alert.occurredAt,
      lastSeen: timestamp,
      lastChange: isNew || escalated ? timestamp : previous.lastChange,
      ntfy,
    };
  }
  // }}}

  // {{{ ntfy
  function ntfyMessage(entry, timestamp) {
    const alert = entry.alert;
    const resolved = alert.status === 'resolved';
    const lines = [];
    if (entry.ntfy.lastSent && !entry.ntfy.pending && !resolved) lines.push('Still unresolved.');
    // Quiet hours and retries can hold a push back for hours; say when it began.
    if (!resolved && timestamp - entry.firstSeen > 10 * MINUTE) lines.push(`Since ${berlinTime(entry.firstSeen)}.`);
    if (resolved && entry.resolvedAt) lines.push(`Recovered at ${berlinTime(entry.resolvedAt)}.`);
    if (lines.length) lines.push('');
    lines.push(alert.message || alert.title);
    return lines.join('\n');
  }

  async function publish(entry, timestamp) {
    const alert = entry.alert;
    const spec = SPEC[alert.severity];
    const resolved = alert.status === 'resolved';
    const response = await httpRequest({
      method: 'POST', url: env.NTFY_URL,
      headers: {Authorization: `Bearer ${env.NTFY_TOKEN}`},
      body: {topic: env.NTFY_TOPIC,
        title: `${resolved ? '[OK]' : spec.prefix} ${alert.host}/${alert.service} · ${alert.title}`,
        message: ntfyMessage(entry, timestamp),
        priority: resolved ? 3 : spec.priority,
        tags: resolved ? ['white_check_mark'] : [spec.tag, ...alert.tags],
        ...(alert.url ? {click: alert.url} : {})},
      json: true, timeout: 15000,
    });
    if (response?.status >= 400 || response?.ok === false) throw new Error(`Publish failed with status ${response.status}`);
  }

  async function drainNtfy(alerts, timestamp) {
    const quiet = isQuiet(timestamp);
    let sent = 0;
    let failed = 0;
    // The incident they rode along with is over while these persist. The most
    // severe of them pages; the rest ride along with that one instead.
    const orphans = Object.entries(alerts)
      .filter(([, entry]) => entry.ntfy.absorbedBy && entry.alert.status === 'firing'
        && alerts[entry.ntfy.absorbedBy]?.alert.status !== 'firing')
      .sort(([, a], [, b]) => rank(b.alert.severity) - rank(a.alert.severity));
    for (const [fingerprint, entry] of orphans) {
      delete entry.ntfy.absorbedBy;
      const by = absorber(alerts, fingerprint, entry.alert);
      if (by) entry.ntfy.absorbedBy = by;
      else entry.ntfy.pending = true;
    }
    for (const [fingerprint, entry] of Object.entries(alerts)) {
      const alert = entry.alert;
      const ntfy = entry.ntfy;
      const resolved = alert.status === 'resolved';
      const due = ntfy.pending || (alert.kind !== 'event' && !resolved && !ntfy.absorbedBy
        && ntfy.lastSent && timestamp - ntfy.lastSent >= DAY);
      if (!due) continue;
      if (quiet && (resolved || alert.severity !== 'critical')) continue;
      if (ntfy.retryAt && timestamp < ntfy.retryAt) continue;
      ntfy.lastAttempt = timestamp;
      try {
        await publish(entry, timestamp);
      } catch (error) {
        // One entry ntfy rejects must not hold back the others behind it.
        failed += 1;
        ntfy.failures = (ntfy.failures ?? 0) + 1;
        ntfy.lastError = clean(error?.message ?? error, 300);
        if (ntfy.failures >= MAX_ATTEMPTS) ntfy.retryAt = timestamp + HOUR;
        recordTarget('ntfy', timestamp, ntfy.lastError);
        console.error(`alert-router: ntfy ${JSON.stringify(fingerprint)} failed (attempt ${ntfy.failures}${ntfy.retryAt ? ', deferred one hour' : ''}): ${ntfy.lastError}`);
        continue;
      }
      sent += 1;
      recordTarget('ntfy', timestamp);
      Object.assign(ntfy, {pending: false, failures: 0, retryAt: null, lastError: null});
      if (resolved) ntfy.lastResolvedSent = timestamp;
      else ntfy.lastSent = timestamp;
    }
    return {sent, failed};
  }
  // }}}

  function prune(alerts, timestamp) {
    for (const [fingerprint, entry] of Object.entries(alerts)) {
      if (entry.ntfy.pending) continue;
      if (entry.alert.status === 'resolved') delete alerts[fingerprint];
      else if (entry.alert.kind === 'event' && timestamp - (entry.ntfy.lastSent ?? entry.lastSeen) > 7 * DAY) {
        delete alerts[fingerprint];
      }
    }
  }

  async function route(alertArray) {
    const timestamp = clock();
    const alerts = Object.assign(Object.create(null), structuredClone({...state.alerts}));
    for (const raw of alertArray) receive(alerts, raw, timestamp);
    // Persist receipts before publishing anything: a failed publish must not
    // lose the alerts that arrived with this call. A failed write leaves the
    // previous state in place, so the caller's retry is not half-applied.
    const before = state.alerts;
    state.alerts = alerts;
    try {
      await save();
    } catch (error) {
      state.alerts = before;
      throw error;
    }
    const {sent, failed} = await drainNtfy(alerts, timestamp);
    prune(alerts, timestamp);
    await save();
    return {sent, failed, queued: Object.values(alerts).filter((entry) => entry.ntfy.pending).length};
  }


  function submit(alertArray) {
    if (!Array.isArray(alertArray)) return Promise.reject(new TypeError('Alerts must be an array'));
    return serialized(() => route(alertArray));
  }

  function status() {
    return serialized(async () => {
      const entries = Object.values(state.alerts);
      return {
        open: entries.filter((entry) => entry.alert.status === 'firing').length,
        ntfy: {pending: entries.filter((entry) => entry.ntfy.pending).length,
          failing: entries.filter((entry) => entry.ntfy.failures > 0).length, ...state.targets.ntfy},
      };
    });
  }

  return {submit, status};
}

async function defaultPublish({url, headers, body, timeout}) {
  const response = await fetch(url, {
    method: 'POST', headers: {...headers, 'content-type': 'application/json'},
    body: JSON.stringify(body), signal: AbortSignal.timeout(timeout),
  });
  if (!response.ok) throw new Error(`Publish failed with status ${response.status}`);
  return response;
}

async function startServer() {
  const statePath = process.env.ALERT_ROUTER_STATE || '/var/lib/n8n-alert-router/state.json';
  const port = Number(process.env.PORT || 8508);
  const router = createRouter({statePath});
  const server = http.createServer(async (request, response) => {
    if (request.method === 'GET' && request.url === '/status') {
      try {
        response.writeHead(200, {'content-type': 'application/json'}).end(JSON.stringify(await router.status()));
      } catch {
        response.writeHead(503).end();
      }
      return;
    }
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
  const drain = setInterval(() => {
    router.submit([])
      .catch((error) => console.error(`alert-router: drain failed: ${error?.message ?? error}`));
  }, 60_000);
  drain.unref();
  return {server, drain, router};
}

if (require.main === module) {
  startServer().catch((error) => {
    console.error(`alert-router: start failed: ${error?.message ?? error}`);
    process.exitCode = 1;
  });
}
module.exports = {createRouter, normalize};
