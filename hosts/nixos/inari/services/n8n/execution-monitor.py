#!/usr/bin/env python3
"""Report active n8n workflow execution failures without reading payloads."""

import argparse
import contextlib
import json
import os
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path
from urllib.error import URLError
from urllib.parse import quote
from urllib.request import Request, urlopen
from zoneinfo import ZoneInfo

FAILED = {"error", "crashed"}


def collect_events(database, editor_url):
    """Return one generic failure or recovery event per workflow.

    A workflow deactivated after a failure gets a recovery event, so its alert
    closes instead of repeating every day.
    """
    uri = f"file:{database}?mode=ro"
    with sqlite3.connect(uri, uri=True, timeout=5) as db:
        db.row_factory = sqlite3.Row
        rows = db.execute(
            """SELECT w.id AS workflow_id, w.name AS workflow_name, w.active,
                      e.status, e.mode, e.id AS execution_id
               FROM workflow_entity AS w
               JOIN execution_entity AS e ON e.workflowId = w.id
               WHERE e.deletedAt IS NULL
                 AND e.stoppedAt IS NOT NULL AND e.status IN ('success', 'error', 'crashed')
                 AND e.mode NOT IN ('manual', 'error')
                 AND e.id = (
                   SELECT MAX(e2.id) FROM execution_entity AS e2
                   WHERE e2.workflowId = w.id AND e2.deletedAt IS NULL
                     AND e2.stoppedAt IS NOT NULL AND e2.status IN ('success', 'error', 'crashed')
                     AND e2.mode NOT IN ('manual', 'error')
                 )"""
        ).fetchall()
    events = []
    for row in rows:
        failed = row["status"] in FAILED
        if not row["active"]:
            if not failed:
                continue
            failed = False
            outcome = ("deactivated", "was deactivated after a failure")
        elif failed:
            outcome = ("failed", "failed")
        else:
            outcome = ("recovered", "completed successfully after a failure")
        name = row["workflow_name"] or "Workflow"
        events.append(
            {
                "source": "automation",
                "host": "inari",
                "service": "n8n",
                "severity": "warning",
                "title": f"n8n workflow {outcome[0]}: {name}",
                "message": f"The scheduled workflow {name} {outcome[1]}. Review its execution in n8n: {editor_url.rstrip('/')}/workflow/{row['workflow_id']}",
                "fingerprint": f"workflow:{row['workflow_id']}",
                "resolved": not failed,
            }
        )
    return events


def post_event(url, event):
    request = Request(
        url,
        data=json.dumps(event).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urlopen(request, timeout=10) as response:
        if response.status >= 300:
            raise RuntimeError("alert router rejected event")


def utcnow():
    return datetime.now(timezone.utc)


def atomic_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(path.name + ".tmp")
    temp.write_text(json.dumps(value))
    os.replace(temp, path)


def post_ntfy(base_url, topic, token, title, message, priority):
    request = Request(
        f"{base_url.rstrip('/')}/{quote(topic, safe='')}",
        data=message.encode(),
        headers={
            "Title": title,
            "Priority": str(priority),
            "Authorization": f"Bearer {token}",
        },
        method="POST",
    )
    with urlopen(request, timeout=10) as response:
        if response.status >= 300:
            raise RuntimeError("ntfy rejected alert")


def send_ntfy(title, message, priority):
    post_ntfy(
        os.environ["NTFY_URL"],
        os.environ["NTFY_TOPIC"],
        os.environ["NTFY_TOKEN"],
        title,
        message,
        priority,
    )


def read_state(path):
    try:
        with open(path) as handle:
            return json.load(handle)
    except FileNotFoundError:
        return {}


# The timer fires every 5 minutes and an n8n restart (imports run in
# ExecStartPre) takes several minutes, so a single failed run is routine.
# Three in a row is a real outage.
FAILURES_BEFORE_ALERT = 3


UNAVAILABLE = {
    "source": "automation",
    "severity": "warning",
    "title": "n8n execution monitor cannot check workflows",
    "message": "The n8n execution monitor could not read its database.",
    "fingerprint": "monitor:unavailable",
}


def handle_unavailable(path, now, webhook):
    state = read_state(path)
    failures = state.get("failures", 0) + 1
    last = state.get("last_failure_sent", 0)
    state = {
        "failures": failures,
        "unavailable": state.get("unavailable", False),
        "last_failure_sent": last,
    }
    # Persist the count first so a failing ntfy send does not reset the streak.
    atomic_json(path, state)
    # The monitoring watchdog publishes straight to ntfy when the router is
    # down. Once the legacy paths are retired, this one only tells the router,
    # which covers a database failure the watchdog cannot see; if the router
    # is down too, the watchdog reports that.
    if os.environ.get("DIRECT_NTFY_FALLBACK", "true") == "false":
        if failures >= FAILURES_BEFORE_ALERT:
            post_event(webhook, {**UNAVAILABLE, "resolved": False})
            state["routed"] = True
            atomic_json(path, state)
        return
    if failures >= FAILURES_BEFORE_ALERT and now.timestamp() - last >= 86400:
        send_ntfy(
            "[CRIT] n8n monitoring unavailable",
            "The n8n execution monitor could not reach its database or alert router.",
            5,
        )
        state["unavailable"] = True
        state["last_failure_sent"] = now.timestamp()
        atomic_json(path, state)


def handle_recovery(path, now, webhook):
    state = read_state(path)
    if state.get("routed"):
        post_event(webhook, {**UNAVAILABLE, "resolved": True})
    if not state.get("unavailable"):
        # Outage never reached a notification, so there is nothing to retract.
        if state:
            Path(path).unlink(missing_ok=True)
        return
    local = now.astimezone(ZoneInfo("Europe/Berlin"))
    if local.hour < 7 or local.hour >= 22:
        return
    send_ntfy(
        "n8n monitoring recovered",
        "The n8n execution monitor can reach its database and alert router again.",
        3,
    )
    Path(path).unlink(missing_ok=True)


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--database", required=True)
    parser.add_argument(
        "--webhook",
        default=os.environ.get("ALERT_WEBHOOK_URL"),
        required=not os.environ.get("ALERT_WEBHOOK_URL"),
    )
    parser.add_argument("--editor-url", required=True)
    parser.add_argument("--state", required=True)
    args = parser.parse_args(argv)
    now = utcnow()
    try:
        post_event(
            args.webhook,
            {
                "source": "automation",
                "severity": "warning",
                "title": "Execution monitor heartbeat",
                "message": "The n8n execution monitor completed a database check.",
                "fingerprint": "monitor:heartbeat",
                "resolved": True,
            },
        )
        for event in collect_events(args.database, args.editor_url):
            post_event(args.webhook, event)
        handle_recovery(args.state, now, args.webhook)
    except (OSError, sqlite3.Error, URLError, RuntimeError, KeyError, ValueError):
        with contextlib.suppress(OSError, URLError, RuntimeError, KeyError, ValueError):
            handle_unavailable(args.state, now, args.webhook)
        print("n8n execution monitor failed", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
