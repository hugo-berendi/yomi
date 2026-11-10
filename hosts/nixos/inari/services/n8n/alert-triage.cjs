'use strict';

// Hermes triage target of the alert router.
//
// Everything Hermes sees is collected here, deterministically and bounded:
// a few metrics around the start of the alert, journal lines from Loki with
// anything credential-shaped removed, and which system units the last
// activated generation changed. The model gets this as data and only writes
// an assessment. It has no tools to gather more, so an injected log line can
// at worst mislead the text, not act.
//
// Delivery is a signed POST to the Hermes gateway's webhook platform on
// loopback. Hermes acknowledges only after it has durably recorded the
// delivery and treats a repeated delivery id as a duplicate, which is what
// makes the router's retries after a crash safe.

const crypto = require('node:crypto');
const fs = require('node:fs/promises');
const path = require('node:path');

const MINUTE = 60 * 1000;
const QUERY_TIMEOUT = 4000;
const LOG_LINES = 30;
const LOG_LINE_CHARS = 240;
const CONTEXT_CHARS = 14000;

const berlin = (timestamp) => new Intl.DateTimeFormat('de-DE', {
  timeZone: 'Europe/Berlin', day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit',
}).format(new Date(timestamp));
const clock = (timestamp) => new Intl.DateTimeFormat('de-DE', {
  timeZone: 'Europe/Berlin', hour: '2-digit', minute: '2-digit', second: '2-digit',
}).format(new Date(timestamp));

// {{{ Sanitizing
// Logs go to a model and, as its answer, into a chat. Strip what must never
// travel: credentials in their common shapes, addresses that identify people,
// and query strings, which is where tokens end up in access logs.
const REDACTIONS = [
  [/\b(authorization|proxy-authorization|cookie|set-cookie)(["']?\s*[:=]\s*["']?)(?:(?:bearer|basic|token|digest)\s+)?[^\s"',]+(?:;\s*[^\s"',;]+)*/gi, '$1$2[entfernt]'],
  [/\b(bearer|basic|token)\s+[A-Za-z0-9._~+/=-]{8,}/gi, '$1 [entfernt]'],
  [/\b([A-Za-z0-9_-]*(?:passw(?:or)?d|secret|token|api[_-]?key|apikey|access[_-]?key|private[_-]?key|session|signature|credential)[A-Za-z0-9_-]*)(["']?\s*[:=]\s*["']?)[^\s"'&,;]+/gi, '$1$2[entfernt]'],
  [/\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}/g, '[jwt entfernt]'],
  [/-----BEGIN [A-Z ]+-----[\s\S]*?(-----END [A-Z ]+-----|$)/g, '[schlüssel entfernt]'],
  [/\b[a-z][a-z0-9+.-]*:\/\/[^\s/@:]+:[^\s/@]+@/gi, 'scheme://[entfernt]@'],
  [/\?[^\s"']*/g, '?[…]'],
  [/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/g, '[mail]'],
  [/\b(?=[A-Za-z0-9+/_-]*\d)(?=[A-Za-z0-9+/_-]*[A-Za-z])[A-Za-z0-9+/_-]{32,}={0,2}/g, '[langer wert]'],
];
function sanitize(text, limit = LOG_LINE_CHARS) {
  // eslint-disable-next-line no-control-regex
  let value = String(text ?? '').replace(/\u001b\[[0-9;]*[A-Za-z]/g, '').replace(/[\u0000-\u0008\u000b-\u001f\u007f]/g, ' ');
  for (const [pattern, replacement] of REDACTIONS) value = value.replace(pattern, replacement);
  value = value.replace(/\s+/g, ' ').trim();
  return value.length > limit ? `${value.slice(0, limit - 1)}…` : value;
}
// }}}

// {{{ Collection
async function getJson(fetchImpl, url, timeout = QUERY_TIMEOUT) {
  const response = await fetchImpl(url, {signal: AbortSignal.timeout(timeout)});
  if (!response.ok) throw new Error(`HTTP ${response.status}`);
  return response.json();
}

function promQuery(fetchImpl, base, query, at) {
  const url = new URL('/api/v1/query', base);
  url.searchParams.set('query', query);
  url.searchParams.set('time', String(at / 1000));
  return getJson(fetchImpl, url).then((body) => {
    if (body?.status !== 'success') throw new Error('query rejected');
    return body.data?.result ?? [];
  });
}

const escapeRegex = (text) => text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const escapeLabel = (text) => text.replace(/\\/g, '\\\\').replace(/"/g, '\\"');

async function findUnits(fetchImpl, base, alert, at) {
  if (alert.labels.unit) return [alert.labels.unit];
  const service = escapeLabel(escapeRegex(alert.service));
  const series = await promQuery(fetchImpl, base,
    `max by (name, state) (node_systemd_unit_state{name=~"(${service}|${service}-[A-Za-z0-9@_.-]+|[A-Za-z0-9@_.-]+-${service})\\\\.service"})`,
    at);
  const units = new Map();
  for (const item of series) {
    if (Number(item.value?.[1]) !== 1) continue;
    units.set(item.metric.name, item.metric.state);
  }
  const score = ([unit, state]) => (unit === `${alert.service}.service` ? 0 : state === 'failed' ? 1 : /^(active|activating|reloading)$/.test(state) ? 2 : 3);
  return [...units].sort((a, b) => score(a) - score(b) || a[0].length - b[0].length).slice(0, 3).map(([unit]) => unit);
}

async function metrics(fetchImpl, base, alert, units, at) {
  const lines = [];
  const missing = [];
  const one = async (label, query, format) => {
    try {
      const result = await promQuery(fetchImpl, base, query, at);
      if (!result.length) {
        missing.push(label);
        return;
      }
      for (const item of result.slice(0, 4)) lines.push(`${label}: ${format(item)}`);
    } catch (error) {
      missing.push(`${label} (${sanitize(error?.message ?? error, 60)})`);
    }
  };
  const number = (item, digits = 0) => Number(item.value[1]).toFixed(digits);
  await Promise.all([
    one('Last (1 min) je Kern', 'node_load1 / scalar(count(node_cpu_seconds_total{mode="idle"}))', (item) => number(item, 2)),
    one('Arbeitsspeicher belegt %', '100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)', (item) => number(item)),
    one('Dateisystem belegt %',
      '100 * (1 - node_filesystem_avail_bytes{mountpoint=~"^(/|/persist/state|/raid5pool|/nix)$"} / node_filesystem_size_bytes{mountpoint=~"^(/|/persist/state|/raid5pool|/nix)$"})',
      (item) => `${item.metric.mountpoint} ${number(item)}`),
    one('Fehlgeschlagene Units', 'node_systemd_unit_state{state="failed"} == 1', (item) => item.metric.name),
    one('Scrape-Ziele ohne Antwort', 'up == 0', (item) => `${item.metric.job} ${item.metric.instance}`),
    ...units.map((unit) => one(`Unit ${unit}`,
      `node_systemd_unit_state{name="${escapeLabel(unit)}"} == 1`, (item) => item.metric.state)),
  ]);
  // No failed units and no dead targets are good news, not missing data.
  const expectedEmpty = new Set(['Fehlgeschlagene Units', 'Scrape-Ziele ohne Antwort']);
  return {lines, missing: missing.filter((label) => !expectedEmpty.has(label))};
}

async function logs(fetchImpl, base, alert, units, start, end) {
  const selector = units.length
    ? `{unit=~"${units.map(escapeRegex).map(escapeLabel).join('|')}"}`
    : `{job="systemd-journal"} |~ "(?i)${escapeLabel(escapeRegex(alert.service))}"`;
  const url = new URL('/loki/api/v1/query_range', base);
  url.searchParams.set('query', selector);
  url.searchParams.set('start', String(BigInt(Math.floor(start)) * 1000000n));
  url.searchParams.set('end', String(BigInt(Math.floor(end)) * 1000000n));
  url.searchParams.set('limit', '200');
  url.searchParams.set('direction', 'backward');
  const body = await getJson(fetchImpl, url);
  const entries = [];
  for (const stream of body?.data?.result ?? []) {
    for (const [nanos, line] of stream.values ?? []) {
      entries.push({time: Number(BigInt(nanos) / 1000000n), unit: stream.stream?.unit ?? '', level: stream.stream?.level ?? '', line});
    }
  }
  entries.sort((a, b) => a.time - b.time);
  // Errors first, then the latest context lines: the onset is usually there.
  const important = (entry) => /^(emerg|alert|crit|err|warning)$/.test(entry.level)
    || /(?:error|fail|fatal|panic|denied|refused|timeout|timed out|oom|killed|exception|traceback)/i.test(entry.line);
  const chosen = [...entries.filter(important).slice(-LOG_LINES)];
  for (const entry of entries.slice().reverse()) {
    if (chosen.length >= LOG_LINES) break;
    if (!chosen.includes(entry)) chosen.push(entry);
  }
  chosen.sort((a, b) => a.time - b.time);
  return {
    selector, total: entries.length,
    lines: chosen.map((entry) => `${clock(entry.time)} ${entry.unit ? entry.unit + ' ' : ''}${entry.level ? `[${entry.level}] ` : ''}${sanitize(entry.line)}`),
  };
}

async function unitTargets(directory) {
  const result = new Map();
  for (const entry of await fs.readdir(directory, {withFileTypes: true})) {
    const full = path.join(directory, entry.name);
    if (entry.isSymbolicLink()) result.set(entry.name, await fs.readlink(full));
    else if (entry.isDirectory()) {
      const inner = await fs.readdir(full);
      const targets = await Promise.all(inner.sort().map((name) => fs.readlink(path.join(full, name)).catch(() => name)));
      result.set(entry.name.replace(/\.d$/, ''), (result.get(entry.name.replace(/\.d$/, '')) ?? '') + targets.join(','));
    }
  }
  return result;
}

// The last activations tell whether an alert follows a change to the system.
// The flake records no git revision in the generation, so this reports
// generation numbers, activation times and the units whose definitions
// changed, which is what a switch acts on.
async function configuration(profiles, currentSystem, at) {
  const links = [];
  for (const name of await fs.readdir(profiles)) {
    const match = /^system-(\d+)-link$/.exec(name);
    if (!match) continue;
    const full = path.join(profiles, name);
    const [target, stat] = await Promise.all([fs.readlink(full), fs.lstat(full)]);
    links.push({number: Number(match[1]), target: path.resolve(profiles, target), time: stat.mtimeMs});
  }
  links.sort((a, b) => b.number - a.number);
  const current = await fs.realpath(currentSystem);
  const index = links.findIndex((link) => link.target === current);
  if (index < 0) return {lines: ['Aktive Generation nicht in den Systemprofilen gefunden.'], changed: []};
  const active = links[index];
  const previous = links[index + 1];
  const lines = [`Aktive Generation ${active.number}, erstellt ${berlin(active.time)} (${Math.round((at - active.time) / MINUTE)} min vor Alarmbeginn).`];
  if (index > 0) lines.push(`Achtung: neuere, nicht aktivierte Generation ${links[0].number} vorhanden.`);
  let changed = [];
  if (previous) {
    const [now, before] = await Promise.all([
      unitTargets(path.join(current, 'etc/systemd/system')),
      unitTargets(path.join(previous.target, 'etc/systemd/system')),
    ]);
    changed = [...new Set([...now.keys(), ...before.keys()])]
      .filter((unit) => now.get(unit) !== before.get(unit) && !/\.(wants|requires|upholds)$/.test(unit))
      .sort();
    lines.push(`Gegenüber Generation ${previous.number} (${berlin(previous.time)}) geänderte Units: ${changed.length ? changed.slice(0, 40).join(', ') + (changed.length > 40 ? `, … (${changed.length})` : '') : 'keine'}.`);
  }
  return {lines, changed};
}
// }}}

// {{{ Rendering
const SEVERITY = {critical: 'KRITISCH', warning: 'WARNUNG', info: 'INFO'};

async function describe(deps, entry) {
  const {fetchImpl, env} = deps;
  const alert = entry.alert;
  const start = entry.firstSeen;
  const out = [
    `### ${SEVERITY[alert.severity]} ${alert.host}/${alert.service}: ${sanitize(alert.title, 200)}`,
    `Quelle: ${alert.source} · Fingerprint: ${sanitize(alert.fingerprint, 120)} · seit ${berlin(start)}${alert.status === 'resolved' ? ' · inzwischen entwarnt' : ''}`,
  ];
  if (alert.message) out.push(`Meldung: ${sanitize(alert.message, 600)}`);
  const labels = Object.entries(alert.labels ?? {});
  if (labels.length) out.push(`Labels: ${labels.map(([key, value]) => `${key}=${sanitize(value, 80)}`).join(', ')}`);

  let units = [];
  try {
    units = await findUnits(fetchImpl, env.PROMETHEUS_URL, alert, start);
  } catch {
    // reported below with the other missing data
  }
  const measured = await metrics(fetchImpl, env.PROMETHEUS_URL, alert, units, start).catch((error) => ({
    lines: [], missing: [`Prometheus nicht erreichbar (${sanitize(error?.message ?? error, 60)})`],
  }));
  out.push('', `Messwerte bei Alarmbeginn (Prometheus):`);
  out.push(...(measured.lines.length ? measured.lines.map((line) => `- ${line}`) : ['- keine']));
  if (measured.missing.length) out.push(`Fehlende Messdaten: ${measured.missing.join('; ')}`);

  try {
    const found = await logs(fetchImpl, env.LOKI_URL, alert, units, start - 15 * MINUTE, Math.min(start + 5 * MINUTE, deps.now()));
    out.push('', `Logs (Loki ${found.selector}, ${clock(start - 15 * MINUTE)}–${clock(start + 5 * MINUTE)}, ${found.lines.length} von ${found.total} Zeilen, bereinigt):`);
    out.push(...(found.lines.length ? found.lines : ['(keine Zeilen — Loki hat für diesen Zeitraum nichts gespeichert)']));
  } catch (error) {
    out.push('', `Logs: Loki nicht abfragbar (${sanitize(error?.message ?? error, 80)}).`);
  }

  try {
    const config = await configuration(env.SYSTEM_PROFILES, env.CURRENT_SYSTEM, start);
    out.push('', 'Konfiguration:', ...config.lines);
    const touched = units.filter((unit) => config.changed.includes(unit));
    if (touched.length) out.push(`Betroffene Units unter den geänderten: ${touched.join(', ')}.`);
  } catch (error) {
    out.push('', `Konfiguration: nicht lesbar (${sanitize(error?.message ?? error, 80)}).`);
  }
  return out.join('\n');
}

function others(entries) {
  if (!entries.length) return '';
  return ['', '', '### Weitere offene Alarme', ...entries.slice(0, 10).map((entry) =>
    `- ${SEVERITY[entry.alert.severity]} ${entry.alert.host}/${entry.alert.service}: ${sanitize(entry.alert.title, 120)} (seit ${berlin(entry.firstSeen)})`)].join('\n');
}

async function render(deps, delivery, items, open) {
  const parts = [];
  for (const [index, entry] of items.entries()) {
    parts.push(`## Alarm ${index + 1} von ${items.length}\n${await describe(deps, entry)}`);
  }
  let context = parts.join('\n\n') + others(open);
  if (context.length > CONTEXT_CHARS) context = `${context.slice(0, CONTEXT_CHARS - 40)}\n… (gekürzt)`;
  return context;
}

function notice(items) {
  // The all-clear needs no model: Hugo already has the analysis in the chat.
  const lines = items.map((entry) => {
    const minutes = Math.max(1, Math.round(((entry.resolvedAt ?? entry.lastChange) - entry.firstSeen) / MINUTE));
    return `✅ Entwarnung ${entry.alert.host}/${entry.alert.service}: ${sanitize(entry.alert.title, 160)} — wieder in Ordnung seit ${berlin(entry.resolvedAt ?? entry.lastChange)} (Dauer etwa ${minutes} min).`;
  });
  return lines.join('\n');
}
// }}}

function sign(secret, timestamp, body) {
  return crypto.createHmac('sha256', secret).update(`${timestamp}.`).update(body).digest('hex');
}

async function createTriage({env = process.env, fetchImpl = fetch, now = () => Date.now()} = {}) {
  const url = env.HERMES_WEBHOOK_URL;
  const file = env.HERMES_WEBHOOK_SECRET_FILE
    || (env.CREDENTIALS_DIRECTORY ? path.join(env.CREDENTIALS_DIRECTORY, 'hermes-webhook') : '');
  if (!url || !file) return null;
  let secret;
  try {
    secret = (await fs.readFile(file, 'utf8')).trim();
  } catch {
    return null;
  }
  if (secret.length < 32) return null;
  const deps = {
    fetchImpl, now,
    env: {
      PROMETHEUS_URL: env.PROMETHEUS_URL || 'http://127.0.0.1:9090',
      LOKI_URL: env.LOKI_URL || 'http://127.0.0.1:3100',
      SYSTEM_PROFILES: env.SYSTEM_PROFILES || '/nix/var/nix/profiles',
      CURRENT_SYSTEM: env.CURRENT_SYSTEM || '/run/current-system',
    },
  };

  async function post(route, id, payload) {
    const body = JSON.stringify(payload);
    const timestamp = String(Math.floor(now() / 1000));
    const response = await fetchImpl(`${url.replace(/\/$/, '')}/${route}`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'X-Request-ID': id,
        'X-Webhook-Timestamp': timestamp,
        'X-Webhook-Signature-V2': sign(secret, timestamp, body),
      },
      body, signal: AbortSignal.timeout(15000),
    });
    // 202 accepted, 200 duplicate (already recorded): both mean Hermes has it.
    if (response.status === 200 || response.status === 202) return {ok: true, status: response.status};
    return {ok: false, status: response.status, error: `Hermes answered HTTP ${response.status}`};
  }

  return {
    async deliver(delivery, items, open) {
      if (!items.length) return {ok: true};
      if (delivery.phase === 'resolved') {
        return post('alert-notice', delivery.id, {event_type: 'alert-notice', message: notice(items)});
      }
      const context = await render(deps, delivery, items, open);
      return post('alert-triage', delivery.id, {
        event_type: 'alert-triage', count: String(items.length), context,
      });
    },
  };
}

module.exports = {createTriage, sanitize, sign, render, configuration};
