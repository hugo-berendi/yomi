#!/usr/bin/env python3
"""Watch the monitoring chain itself and send an outside heartbeat.

Every other producer on inari reports what it measures. None of them notices
when the measuring stops: Loki answering /ready while it refuses every push,
Prometheus serving stale samples, Gatus no longer probing, the alert router or
ntfy gone. This checks the consumers' actual behaviour, reports through the
alert router, and falls back to publishing straight to ntfy when the router is
the thing that is down.

The heartbeat goes to a check hosted outside inari. It reports success only
when the router and ntfy work, so a dead box, a dead uplink and a broken push
path all end in the same mail from the outside service.
"""

import argparse
import json
import os
import sys
import time
from pathlib import Path
from urllib.error import URLError
from urllib.parse import quote, urlencode
from urllib.request import Request, urlopen
from zoneinfo import ZoneInfo
from datetime import datetime, timezone

TIMEOUT = 8
# Two runs two minutes apart: a service restart during a switch is not an outage.
FAILURES_BEFORE_ALERT = 2


def fetch(url, *, data=None, headers=None, method=None, timeout=TIMEOUT):
    request = Request(url, data=data, headers=headers or {}, method=method)
    with urlopen(request, timeout=timeout) as response:
        body = response.read()
        if response.status >= 300:
            raise RuntimeError(f"HTTP {response.status}")
        return body


def fetch_json(url, **kwargs):
    return json.loads(fetch(url, **kwargs) or b"null")


def prom(base, query):
    body = fetch_json(f"{base}/api/v1/query?{urlencode({'query': query})}")
    if body.get("status") != "success":
        raise RuntimeError("query rejected")
    return body["data"]["result"]


# {{{ Checks
# Each returns None when healthy, or a short German description of the fault.


def check_router(env, now):
    status = fetch_json(f"{env['ALERT_ROUTER_URL'].rsplit('/', 1)[0]}/status")
    ntfy = status.get("ntfy") or {}
    if ntfy.get("failing"):
        return f"Alarmrouter erreicht ntfy nicht: {ntfy.get('failing')} Meldung(en) hängen ({ntfy.get('lastError') or 'unbekannter Fehler'})."
    return None


def check_ntfy(env, now):
    if not fetch_json(f"{env['NTFY_URL']}/v1/health").get("healthy"):
        return "ntfy meldet sich als nicht gesund."
    return None


def check_prometheus(env, now):
    fetch(f"{env['PROMETHEUS_URL']}/-/ready")
    age = prom(env["PROMETHEUS_URL"], 'time() - max(timestamp(up{job="inari-system"}))')
    if not age:
        return (
            'Prometheus hat keine Messdaten von inari (up{job="inari-system"} fehlt).'
        )
    seconds = float(age[0]["value"][1])
    if seconds > 180:
        return f"Prometheus-Messdaten sind {int(seconds)} s alt; es wird nicht mehr gesammelt."
    targets = prom(env["PROMETHEUS_URL"], 'count(up{job="inari-system"})')
    expected = int(env.get("EXPECTED_SYSTEM_TARGETS") or 0)
    found = int(float(targets[0]["value"][1])) if targets else 0
    if expected and found < expected:
        return f"Prometheus kennt nur {found} von {expected} Exportern auf inari; Messdaten fehlen."
    return None


def check_grafana(env, now):
    if fetch_json(f"{env['GRAFANA_URL']}/api/health").get("database") != "ok":
        return "Grafana meldet ihre Datenbank als nicht in Ordnung; Alarmregeln werden nicht ausgewertet."
    return None


def check_loki(env, now):
    fetch(f"{env['LOKI_URL']}/ready")
    # /ready stays 200 while the ingester refuses every push, so ask for the
    # journal lines that must have arrived: the journal is never silent.
    query = urlencode(
        {
            "query": 'sum(count_over_time({job="systemd-journal"}[10m]))',
            "time": f"{now:.3f}",
        }
    )
    result = fetch_json(f"{env['LOKI_URL']}/loki/api/v1/query?{query}")["data"][
        "result"
    ]
    lines = float(result[0]["value"][1]) if result else 0
    if lines == 0:
        return "Loki hat in den letzten 10 Minuten keine Journalzeilen gespeichert; Alloy oder die Loki-Aufnahme ist ausgefallen. Logs gehen verloren."
    return None


def check_gatus(env, now):
    endpoints = fetch_json(f"{env['GATUS_URL']}/api/v1/endpoints/statuses")
    newest = 0.0
    for endpoint in endpoints or []:
        for result in endpoint.get("results") or []:
            stamp = result.get("timestamp")
            if stamp:
                newest = max(
                    newest,
                    datetime.fromisoformat(stamp.replace("Z", "+00:00")).timestamp(),
                )
    if not newest:
        return "Gatus liefert keine Prüfergebnisse."
    if now - newest > 300:
        return f"Gatus hat seit {int((now - newest) / 60)} Minuten nichts mehr geprüft."
    return None


def check_n8n(env, now):
    fetch(f"{env['N8N_URL']}/healthz")
    return None


def check_hermes(env, now):
    if not env.get("HERMES_WEBHOOK_HEALTH"):
        return None
    if fetch_json(env["HERMES_WEBHOOK_HEALTH"]).get("status") != "ok":
        return "Der Hermes-Webhook antwortet fehlerhaft."
    return None


CHECKS = {
    # service: (check, severity, title)
    "alert-router": (check_router, "critical", "Alarmzustellung gestört"),
    "ntfy": (check_ntfy, "critical", "ntfy nicht gesund"),
    "prometheus": (check_prometheus, "critical", "Prometheus-Messdaten fehlen"),
    "grafana": (check_grafana, "critical", "Grafana wertet keine Alarme aus"),
    "loki": (check_loki, "warning", "Loki nimmt keine Logs an"),
    "gatus": (check_gatus, "warning", "Gatus prüft nicht mehr"),
    "n8n": (check_n8n, "critical", "n8n nicht erreichbar"),
    "hermes": (check_hermes, "warning", "Hermes-Triage nicht erreichbar"),
}
# }}}


def run_checks(env, now, checks=CHECKS):
    faults = {}
    for service, (check, _, _) in checks.items():
        try:
            fault = check(env, now)
        except (
            OSError,
            URLError,
            RuntimeError,
            ValueError,
            KeyError,
            IndexError,
            TypeError,
        ) as error:
            fault = f"nicht erreichbar oder fehlerhafte Antwort ({type(error).__name__}: {str(error)[:120]})"
        if fault:
            faults[service] = fault
    return faults


def read_state(path):
    try:
        return json.loads(Path(path).read_text())
    except (FileNotFoundError, ValueError):
        return {}


def write_state(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(json.dumps(value))
    os.replace(temporary, path)


def events(faults, state, checks=CHECKS):
    """Router alerts after hysteresis, and the next per-service streaks."""
    streaks = dict(state.get("streaks", {}))
    alerts = []
    for service, (_, severity, title) in checks.items():
        fault = faults.get(service)
        streaks[service] = streaks.get(service, 0) + 1 if fault else 0
        base = {
            "source": "watchdog",
            "host": "inari",
            "service": service,
            "severity": severity,
            "title": title,
            "fingerprint": f"watchdog:{service}",
        }
        if fault and streaks[service] >= FAILURES_BEFORE_ALERT:
            alerts.append({**base, "message": fault})
        elif not fault:
            alerts.append({**base, "resolved": True, "message": "Wieder in Ordnung."})
    return alerts, streaks


def post_router(env, alerts):
    fetch(
        env["ALERT_ROUTER_URL"],
        data=json.dumps(alerts).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
        timeout=30,
    )


def post_ntfy(env, title, message, priority):
    fetch(
        f"{env['NTFY_URL']}/{quote(env['NTFY_TOPIC'], safe='')}",
        data=message.encode(),
        method="POST",
        headers={
            "Title": title,
            "Priority": str(priority),
            "Authorization": f"Bearer {env.get('NTFY_TOKEN', '')}",
        },
    )


def direct_fallback(env, state, router_down, now):
    """Publish straight to ntfy while the router itself is unreachable."""
    fallback = dict(state.get("fallback", {}))
    if router_down:
        fallback["streak"] = fallback.get("streak", 0) + 1
        if (
            fallback["streak"] >= FAILURES_BEFORE_ALERT
            and now - fallback.get("sent", 0) >= 86400
        ):
            post_ntfy(
                env,
                "[CRIT] inari/alert-router · Alarmrouter nicht erreichbar",
                "Der Watchdog erreicht den Alarmrouter nicht. Andere Alarme kommen nicht an, bis er wieder läuft.",
                5,
            )
            fallback["sent"] = now
            fallback["open"] = True
    else:
        if fallback.get("open"):
            local = datetime.fromtimestamp(now, timezone.utc).astimezone(
                ZoneInfo("Europe/Berlin")
            )
            if 7 <= local.hour < 22:
                post_ntfy(
                    env,
                    "[OK] inari/alert-router · Alarmrouter wieder erreichbar",
                    "Der Alarmrouter nimmt wieder Meldungen an.",
                    3,
                )
                fallback = {}
        else:
            fallback = {}
    return fallback


def heartbeat(env, faults):
    """Ping the outside check: success only while pushes can actually go out."""
    path = env.get("HEARTBEAT_URL_FILE")
    if not path or not Path(path).exists():
        return None
    url = Path(path).read_text().strip()
    broken = {
        service: faults[service]
        for service in ("alert-router", "ntfy")
        if service in faults
    }
    if broken:
        summary = "\n".join(f"{service}: {fault}" for service, fault in broken.items())
        fetch(
            url.rstrip("/") + "/fail", data=summary.encode(), method="POST", timeout=10
        )
        return "fail"
    fetch(url, timeout=10)
    return "ok"


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--state", required=True)
    args = parser.parse_args(argv)
    env = dict(os.environ)
    now = time.time()
    state = read_state(args.state)
    faults = run_checks(env, now)
    alerts, streaks = events(faults, state)
    router_down = False
    try:
        post_router(env, alerts)
    except (OSError, URLError, RuntimeError) as error:
        router_down = True
        faults.setdefault(
            "alert-router",
            f"Alarmrouter nimmt keine Meldungen an ({type(error).__name__})",
        )
    status = 0
    try:
        fallback = direct_fallback(env, state, router_down, now)
    except (OSError, URLError, RuntimeError) as error:
        print(f"watchdog: direct ntfy fallback failed: {error}", file=sys.stderr)
        fallback = state.get("fallback", {})
        status = 1
    try:
        beat = heartbeat(env, faults)
    except (OSError, URLError, RuntimeError) as error:
        print(f"watchdog: heartbeat failed: {error}", file=sys.stderr)
        beat = "error"
    write_state(args.state, {"streaks": streaks, "fallback": fallback})
    for service, fault in faults.items():
        print(f"watchdog: {service}: {fault}", file=sys.stderr)
    print(f"watchdog: {len(faults)} fault(s), heartbeat {beat or 'not configured'}")
    return status


if __name__ == "__main__":
    raise SystemExit(main())
