from pathlib import Path
import tempfile
import unittest
from dispatch_core import Dispatcher
from dispatch_store import Store


class DispatchTests(unittest.TestCase):
    def test_lost_launch_reply_reuses_command_and_preserves_task_identity(self):
        with tempfile.TemporaryDirectory() as directory:
            launches, lose = [], [True]

            def rpc(operation, payload=None, **kwargs):
                if operation == "orchestration.subscribeShell":
                    return {
                        "kind": "snapshot",
                        "snapshot": {
                            "projects": [
                                {
                                    "id": "allowed",
                                    "title": "Repo",
                                    "workspaceRoot": "/repo",
                                },
                                {
                                    "id": "forbidden",
                                    "title": "Other",
                                    "workspaceRoot": "/other",
                                },
                            ]
                        },
                    }
                if operation == "orchestration.launchThread":
                    launches.append(payload)
                    if lose[0]:
                        lose[0] = False
                        raise TimeoutError("Lost after server accepted the command")
                    return {
                        "threadId": "mcp:actual",
                        "link": "t3-thread://v2/env/mcp:actual",
                    }
                if operation == "orchestration.getThreadProjection":
                    return {
                        "runs": [{"ordinal": 1, "status": "running"}],
                        "messages": [],
                    }
                if operation == "subscribeServerConfig":
                    return {
                        "config": {
                            "providers": [
                                {
                                    "instanceId": "codex",
                                    "enabled": True,
                                    "installed": True,
                                    "status": "ready",
                                }
                            ]
                        }
                    }
                return {}

            store = Store(Path(directory) / "tasks.sqlite")
            dispatch = Dispatcher(
                {
                    "projectIds": ["allowed"],
                    "publicUrl": "https://t3.example.org",
                    "environmentId": "test-environment",
                    "taste": "Respect the existing design",
                    "routes": {
                        k: {"model": "sol", "effort": "medium"}
                        for k in ("routine", "standard", "complex")
                    },
                },
                store,
                rpc,
                verify_room=lambda config, requested: requested,
            )
            args = {
                "task_key": "event-123:1",
                "project_id": "allowed",
                "description": "Fix the menu",
                "room_id": "!" + "a" * 43,
            }
            self.assertEqual(len(dispatch.projects()), 1)
            with self.assertRaises(TimeoutError):
                dispatch.start(args)
            self.assertEqual(dispatch.start(args)["status"], "running")
            self.assertEqual(store.task(args["task_key"])["thread_id"], "mcp:actual")
            self.assertEqual(launches[0], launches[1])
            self.assertEqual(launches[0]["workspaceStrategy"]["type"], "worktree")
            with self.assertRaises(ValueError):
                dispatch.start({**args, "description": "Different request"})
            with self.assertRaises(ValueError):
                dispatch.start({**args, "task_key": "other", "project_id": "forbidden"})
            with self.assertRaises(ValueError):
                dispatch.stop({"task_key": "unknown", "request_id": "stop-1"})
            dispatch.stop({"task_key": args["task_key"], "request_id": "stop-1"})
            self.assertEqual(store.task(args["task_key"])["last_status"], "stopped")

    def test_changed_ready_pr_waits_for_active_job_before_repair(self):
        import json
        from unittest.mock import patch

        with tempfile.TemporaryDirectory() as directory:
            store = Store(Path(directory) / "db")
            for key, status in [("old", "ready"), ("new", "running")]:
                store.db.execute(
                    "INSERT INTO tasks(task_key,payload,thread_id,room_id,last_status) VALUES(?,?,?,?,?)",
                    (
                        key,
                        json.dumps({"projectId": "allowed"}),
                        key,
                        "!dm:host",
                        status,
                    ),
                )
            store.db.commit()
            calls = []

            def rpc(method, payload, **kwargs):
                if method == "orchestration.getThreadProjection":
                    return {
                        "runs": [
                            {
                                "id": payload["threadId"] + "-run",
                                "ordinal": 1,
                                "status": "completed"
                                if payload["threadId"] == "old"
                                else "running",
                            }
                        ]
                    }
                calls.append((method, payload))
                return {}

            dispatcher = Dispatcher({"environmentId": "test"}, store, rpc)
            with patch(
                "dispatch_core.verify",
                return_value={"state": "failed", "reason": "CI failed"},
            ):
                dispatcher.tick()
                self.assertEqual(calls, [])
                self.assertEqual(store.task("old")["last_status"], "waiting_followup")
                store.db.execute(
                    "UPDATE tasks SET last_status='stopped' WHERE task_key='new'"
                )
                store.db.commit()
                dispatcher.tick()
            self.assertEqual(len(calls), 1)
            self.assertEqual(calls[0][1]["type"], "message.dispatch")
            self.assertEqual(calls[0][1]["threadId"], "old")
            self.assertEqual(store.task("old")["last_status"], "preparing")

    def test_cancellation_with_missing_launch_receipt_blocks_new_work(self):
        import json

        with tempfile.TemporaryDirectory() as directory:
            store = Store(Path(directory) / "db")
            for key, status in [("uncertain", "launching"), ("later", "queued")]:
                store.db.execute(
                    "INSERT INTO tasks(task_key,payload,room_id,last_status) VALUES(?,?,?,?)",
                    (key, json.dumps({}), "!dm:host", status),
                )
            store.db.commit()
            dispatcher = Dispatcher(
                {},
                store,
                lambda *args, **kwargs: self.fail(
                    "Must not launch or send without a receipt"
                ),
            )
            with self.assertRaisesRegex(ValueError, "uncertain"):
                dispatcher.stop({"task_key": "uncertain", "request_id": "stop-1"})
            dispatcher.tick()
            self.assertEqual(store.task("uncertain")["last_status"], "uncertain_launch")
            self.assertEqual(store.task("later")["last_status"], "queued")
            with self.assertRaisesRegex(ValueError, "no active"):
                dispatcher.reply(
                    {
                        "task_key": "uncertain",
                        "request_id": "reply-1",
                        "message": "Continue",
                    }
                )
