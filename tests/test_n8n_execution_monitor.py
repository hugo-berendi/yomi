import importlib.util
import json
import os
import sqlite3
import tempfile
import unittest
from unittest.mock import patch
from datetime import datetime, timezone
from pathlib import Path

SCRIPT = Path(
    os.environ.get(
        "N8N_EXECUTION_MONITOR",
        Path(__file__).parents[1]
        / "hosts/nixos/inari/services/n8n/execution-monitor.py",
    )
)
spec = importlib.util.spec_from_file_location("execution_monitor", SCRIPT)
monitor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(monitor)


class ExecutionMonitorTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.path = Path(self.temp.name) / "db.sqlite"
        db = sqlite3.connect(self.path)
        db.executescript("""
          CREATE TABLE workflow_entity (id TEXT PRIMARY KEY, name TEXT, active BOOLEAN);
          CREATE TABLE execution_entity (
            id INTEGER PRIMARY KEY, workflowId TEXT, finished BOOLEAN, mode TEXT,
            status TEXT, createdAt TEXT, stoppedAt TEXT, deletedAt TEXT
          );
        """)
        self.db = db

    def tearDown(self):
        self.db.close()
        self.temp.cleanup()

    def workflow(self, ident, name, active=1):
        self.db.execute(
            "INSERT INTO workflow_entity VALUES (?, ?, ?)", (ident, name, active)
        )

    def execution(
        self, ident, workflow, status, *, finished=1, mode="trigger", deleted=None
    ):
        self.db.execute(
            "INSERT INTO execution_entity VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (
                ident,
                workflow,
                finished,
                mode,
                status,
                str(ident),
                str(ident) if status != "running" else None,
                deleted,
            ),
        )

    def events(self):
        self.db.commit()
        return monitor.collect_events(str(self.path), "https://n8n.example/")

    def test_only_latest_active_scheduled_terminal_failure_emits_generic_event(self):
        self.workflow("broken", "Payment workflow")
        self.workflow("inactive", "Inactive", active=0)
        self.workflow("manual", "Manual only")
        self.execution(1, "broken", "error", finished=0)
        self.execution(2, "broken", "success")
        self.execution(3, "broken", "error")
        self.execution(4, "inactive", "error")
        self.execution(5, "manual", "error", mode="manual")
        events = self.events()
        self.assertEqual(len(events), 1)
        self.assertEqual(events[0]["fingerprint"], "workflow:broken")
        self.assertEqual(events[0]["severity"], "warning")
        self.assertFalse(events[0]["resolved"])
        self.assertIn("Payment workflow", events[0]["title"] + events[0]["message"])
        self.assertNotIn("error", json.dumps(events[0]).lower())

    def test_success_after_failure_emits_recovery(self):
        self.workflow("recover", "Scheduled job")
        self.execution(1, "recover", "error", finished=0)
        self.execution(2, "recover", "success")
        (event,) = self.events()
        self.assertTrue(event["resolved"])
        self.assertEqual(event["fingerprint"], "workflow:recover")

    def test_newer_running_execution_does_not_hide_failure(self):
        self.workflow("running", "Slow job")
        self.execution(1, "running", "error", finished=0)
        self.execution(2, "running", "running", finished=0)
        (event,) = self.events()
        self.assertFalse(event["resolved"])

    def test_cli_posts_heartbeat_when_there_are_no_executions(self):
        self.db.commit()
        sent = []
        monitor.post_event = lambda url, event: sent.append((url, event))
        args = [
            "--database",
            str(self.path),
            "--webhook",
            "http://router",
            "--editor-url",
            "https://n8n.example/",
            "--state",
            str(self.path.with_name("receipt.json")),
        ]
        self.assertEqual(monitor.main(args), 0)
        self.assertEqual(
            [event["fingerprint"] for _, event in sent], ["monitor:heartbeat"]
        )
        self.assertTrue(sent[0][1]["resolved"])

    def test_cli_posts_generic_event_and_returns_failure_for_router_error(self):
        self.workflow("posted", "Safe title")
        self.execution(1, "posted", "error", finished=0)
        self.db.commit()
        sent = []
        monitor.post_event = lambda url, event: sent.append((url, event))
        args = [
            "--database",
            str(self.path),
            "--webhook",
            "http://router",
            "--editor-url",
            "https://n8n.example/",
            "--state",
            str(self.path.with_name("receipt.json")),
        ]
        self.assertEqual(monitor.main(args), 0)
        self.assertEqual(sent[0][0], "http://router")
        self.assertEqual(sent[0][1]["fingerprint"], "monitor:heartbeat")
        self.assertEqual(sent[1][1]["fingerprint"], "workflow:posted")
        self.assertNotIn("stack", json.dumps(sent[1][1]))
        monitor.post_event = lambda _url, _event: (_ for _ in ()).throw(
            OSError("private detail")
        )
        self.assertEqual(monitor.main(args), 1)

    def test_router_failure_sends_critical_ntfy_once_per_24_hours(self):
        state = self.path.with_name("receipt.json")
        env = {
            "NTFY_URL": "https://ntfy.example",
            "NTFY_TOPIC": "ops",
            "NTFY_TOKEN": "secret-token",
        }
        sent = []
        monitor.post_ntfy = lambda *args: sent.append(args)
        args = [
            "--database",
            str(self.path.with_name("missing.db")),
            "--webhook",
            "http://router",
            "--editor-url",
            "https://n8n.example/",
            "--state",
            str(state),
        ]
        with (
            patch.dict("os.environ", env),
            patch.object(
                monitor,
                "utcnow",
                return_value=datetime(2026, 10, 26, 10, tzinfo=timezone.utc),
            ),
        ):
            self.assertEqual(monitor.main(args), 1)
            self.assertEqual(monitor.main(args), 1)
        self.assertEqual(len(sent), 1)
        self.assertEqual(sent[0][3], "[CRIT] n8n monitoring unavailable")
        self.assertEqual(sent[0][5], 5)
        self.assertEqual(sent[0][2], "secret-token")
        self.assertTrue(state.exists())

    def test_recovery_is_held_at_night_then_sent_and_receipt_cleared(self):
        state = self.path.with_name("receipt.json")
        state.write_text(json.dumps({"unavailable": True, "last_failure_sent": 0}))
        self.workflow("healthy", "Healthy workflow")
        self.execution(1, "healthy", "success")
        self.db.commit()
        sent = []
        monitor.post_event = lambda *_args: None
        monitor.post_ntfy = lambda *args: sent.append(args)
        args = [
            "--database",
            str(self.path),
            "--webhook",
            "http://router",
            "--editor-url",
            "https://n8n.example/",
            "--state",
            str(state),
        ]
        env = {
            "NTFY_URL": "https://ntfy.example",
            "NTFY_TOPIC": "ops",
            "NTFY_TOKEN": "secret-token",
        }
        with (
            patch.dict("os.environ", env),
            patch.object(
                monitor,
                "utcnow",
                return_value=datetime(2026, 10, 26, 2, tzinfo=timezone.utc),
            ),
        ):
            self.assertEqual(monitor.main(args), 0)
        self.assertEqual(sent, [])
        with (
            patch.dict("os.environ", env),
            patch.object(
                monitor,
                "utcnow",
                return_value=datetime(2026, 10, 26, 10, tzinfo=timezone.utc),
            ),
        ):
            self.assertEqual(monitor.main(args), 0)
        self.assertEqual(len(sent), 1)
        self.assertEqual(sent[0][3], "n8n monitoring recovered")
        self.assertEqual(sent[0][5], 3)
        self.assertFalse(state.exists())

    def test_query_is_read_only(self):
        self.workflow("ro", "Readonly")
        self.execution(1, "ro", "error")
        self.db.commit()
        self.events()
        with self.assertRaises(sqlite3.OperationalError):
            sqlite3.connect(f"file:{self.path}?mode=ro", uri=True).execute(
                "INSERT INTO workflow_entity VALUES ('x', 'x', 1)"
            )


if __name__ == "__main__":
    unittest.main()
