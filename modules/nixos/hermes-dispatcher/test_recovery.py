from datetime import datetime, timezone
import json
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest

from dispatch_store import Store
from quota_recovery import recover
from task_followup import request_followup


class RecoveryTests(unittest.TestCase):
    def test_handoff_survives_crash_after_stop_without_changing_worktree(self):
        with tempfile.TemporaryDirectory() as directory:
            store = Store(Path(directory) / "db")
            store.db.execute(
                "INSERT INTO tasks(task_key,payload,thread_id,room_id,last_status) VALUES(?,?,?,?,?)",
                (
                    "task_a",
                    json.dumps({"initialMessage": {"text": "Original"}}),
                    "same-thread",
                    "!dm:host",
                    "running",
                ),
            )
            store.db.commit()
            calls, fail = [], [True]

            def rpc(method, payload, **kwargs):
                if method == "subscribeServerConfig":
                    return {
                        "config": {
                            "providers": [
                                {
                                    "instanceId": "codex",
                                    "usageLimits": {
                                        "checkedAt": datetime.now(
                                            timezone.utc
                                        ).isoformat(),
                                        "windows": [{"usedPercent": 100}],
                                    },
                                },
                                {
                                    "instanceId": "claudeAgent",
                                    "enabled": True,
                                    "installed": True,
                                    "status": "ready",
                                },
                            ]
                        }
                    }
                calls.append(payload)
                if payload["type"] == "message.dispatch" and fail[0]:
                    fail[0] = False
                    raise TimeoutError("Lost reply")
                return {}

            dispatcher = SimpleNamespace(store=store, rpc=rpc, config={"routes": {}})
            state = {
                "status": "failed",
                "latest_run": {"id": "run1", "providerInstanceId": "codex"},
            }
            with self.assertRaises(TimeoutError):
                recover(dispatcher, store.task("task_a"), state)
            self.assertIsNotNone(store.task("task_a")["recovery"])
            # Stop has changed the native status. Persisted intent must still finish.
            self.assertTrue(
                recover(dispatcher, store.task("task_a"), {"status": "cancelled"})
            )
            self.assertEqual(calls[1], calls[3])
            self.assertTrue(all(p["threadId"] == "same-thread" for p in calls))
            self.assertIsNone(store.task("task_a")["recovery"])
            self.assertEqual(store.task("task_a")["last_status"], "preparing")

    def test_user_question_is_not_bypassed_and_followup_retry_keeps_identity(self):
        with tempfile.TemporaryDirectory() as directory:
            store = Store(Path(directory) / "db")
            task = {
                "task_key": "task_a",
                "thread_id": "thread",
                "room_id": "!dm:host",
                "last_status": "waiting",
            }
            dispatcher = SimpleNamespace(
                store=store,
                rpc=lambda *a, **k: self.fail("Must not bypass user"),
                config={},
            )
            self.assertFalse(
                recover(
                    dispatcher, task, {"status": "waiting", "latest_run": {"id": "run"}}
                )
            )
            calls = []
            dispatcher.rpc = lambda method, payload: calls.append(payload)
            state = {"latest_run": {"id": "run"}}
            self.assertTrue(request_followup(dispatcher, task, state, "CI failed"))
            self.assertTrue(request_followup(dispatcher, task, state, "CI failed"))
            self.assertEqual(calls[0], calls[1])
