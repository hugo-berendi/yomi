#!/usr/bin/env python3
"""Report active n8n workflow execution failures without reading payloads."""

import argparse
from datetime import datetime, timezone
from zoneinfo import ZoneInfo
from pathlib import Path
from urllib.parse import quote
import json
import os
import sqlite3
import sys
from urllib.error import URLError
from urllib.request import Request, urlopen

FAILED = {"error", "crashed"}


def collect_events(database, editor_url):
    """Return one generic failure or recovery event per active workflow."""
    uri = f"file:{database}?mode=ro"
    with sqlite3.connect(uri, uri=True, timeout=5) as db:
        db.row_factory = sqlite3.Row
        rows = db.execute(
            """SELECT w.id AS workflow_id, w.name AS workflow_name,
                      e.status, e.mode, e.id AS execution_id
               FROM workflow_entity AS w
               JOIN execution_entity AS e ON e.workflowId = w.id
               WHERE w.active = 1 AND e.deletedAt IS NULL
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
        name = row["workflow_name"] or "Workflow"
        events.append(
            {
                "source": "automation",
                "severity": "warning",
                "title": f"n8n workflow {'failed' if failed else 'recovered'}: {name}",
                "message": f"The scheduled workflow {name} {'failed' if failed else 'completed successfully after a failure'}. Review its execution in n8n: {editor_url.rstrip('/')}/workflow/{row['workflow_id']}",
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


def handle_unavailable(path, now):
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
    if failures >= FAILURES_BEFORE_ALERT and now.timestamp() - last >= 86400:
        send_ntfy(
            "[CRIT] n8n monitoring unavailable",
            "The n8n execution monitor could not reach its database or alert router.",
            5,
        )
        state["unavailable"] = True
        state["last_failure_sent"] = now.timestamp()
        atomic_json(path, state)


def handle_recovery(path, now):
    state = read_state(path)
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
        handle_recovery(args.state, now)
    except (OSError, sqlite3.Error, URLError, RuntimeError, KeyError, ValueError):
        try:
            handle_unavailable(args.state, now)
        except (OSError, URLError, RuntimeError, KeyError, ValueError):
            pass
        print("n8n execution monitor failed", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
