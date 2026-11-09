"""Exercise native MCP calls and persistence at the real controller boundary."""

from pathlib import Path
import tempfile
import unittest

from t3_rpc import T3Rpc


class SupplementTests(unittest.TestCase):
    def test_internal_api_cannot_launch_or_control_threads(self):
        rpc = T3Rpc({})
        with self.assertRaisesRegex(ValueError, "supplement"):
            rpc("orchestration.launchThread", {})

    def test_supplement_credential_has_only_read_scope(self):
        from types import SimpleNamespace
        from unittest.mock import patch

        rpc = T3Rpc(
            {
                "t3": "/t3",
                "baseDirectory": "/owner/.t3",
                "node": "/node",
                "rpcScript": "/rpc",
                "baseUrl": "http://127.0.0.1:8501",
            }
        )
        with patch(
            "t3_rpc.subprocess.run",
            side_effect=[
                SimpleNamespace(stdout="dummy-token"),
                SimpleNamespace(returncode=0, stdout="{}"),
            ],
        ) as run:
            rpc("subscribeServerConfig", {}, first=True)
        argv = run.call_args_list[0].args[0]
        self.assertEqual(
            [argv[i + 1] for i, item in enumerate(argv) if item == "--scope"],
            ["orchestration:read"],
        )


class BackendTests(unittest.TestCase):
    def test_native_launch_result_supplies_actual_thread_id(self):
        from t3_backend import T3Backend

        calls = []

        class Native:
            def call(self, name, args, key=None):
                calls.append((name, args, key))
                if name == "t3_thread_configure":
                    return {
                        "modelSelection": {
                            "instanceId": "codex",
                            "model": "luna",
                            "options": [],
                        }
                    }
                return {
                    "threadId": "mcp:actual",
                    "link": "t3-thread://v2/env/mcp:actual",
                }

        backend = T3Backend(
            Native(), lambda *a, **k: self.fail("No internal control fallback")
        )
        payload = {
            "commandId": "stable",
            "projectId": "repo",
            "title": "Fix",
            "initialMessage": {"text": "Task", "attachments": []},
            "workspaceStrategy": {"type": "worktree", "baseRef": "HEAD"},
            "modelSelection": {"instanceId": "codex", "model": "luna", "options": []},
            "runtimeMode": "full-access",
            "interactionMode": "default",
        }
        result = backend("orchestration.launchThread", payload)
        self.assertEqual(result["threadId"], "mcp:actual")
        # Launch idle, read the stored model back, then send the task.
        self.assertEqual(
            [c[0] for c in calls],
            ["t3_thread_launch", "t3_thread_configure", "t3_thread_send"],
        )
        self.assertEqual(calls[0][1]["clientRequestId"], "stable")
        self.assertNotIn("message", calls[0][1], "no run before the check")
        self.assertNotIn("threadId", calls[0][1])
        self.assertEqual(calls[2][1]["message"], "Task")
        self.assertEqual(calls[2][1]["threadId"], "mcp:actual")
        self.assertEqual(calls[2][2], "stable:start")

    def test_launch_with_a_different_stored_model_never_sends_the_task(self):
        from t3_backend import T3Backend
        from model_selection import ModelNotEnforced

        calls = []

        class Native:
            def call(self, name, args, key=None):
                calls.append(name)
                if name == "t3_thread_configure":
                    # T3 dropped the effort option: medium is not proven.
                    return {
                        "modelSelection": {
                            "instanceId": "claudeAgent",
                            "model": "claude-fable-5-2",
                        }
                    }
                return {"threadId": "idle", "link": "t3://idle"}

        backend = T3Backend(Native(), None)
        with self.assertRaises(ModelNotEnforced) as caught:
            backend(
                "orchestration.launchThread",
                {
                    "commandId": "stable",
                    "projectId": "repo",
                    "title": "Fix",
                    "initialMessage": {"text": "Task", "attachments": []},
                    "workspaceStrategy": {"type": "worktree", "baseRef": "HEAD"},
                    "modelSelection": {
                        "instanceId": "claudeAgent",
                        "model": "claude-fable-5-2",
                        "options": [{"id": "effort", "value": "medium"}],
                    },
                    "runtimeMode": "full-access",
                    "interactionMode": "default",
                },
            )
        self.assertEqual(caught.exception.thread, "idle")
        self.assertNotIn("t3_thread_send", calls)

    def test_input_request_answers_are_writes_with_receipts(self):
        from t3_mcp import is_mutation

        self.assertFalse(is_mutation("t3_pending_request", {"action": "list"}))
        self.assertFalse(is_mutation("t3_pending_request", {"action": "read"}))
        self.assertTrue(is_mutation("t3_pending_request", {"action": "respond"}))
        self.assertTrue(is_mutation("t3_thread_organize", {"action": "settle"}))
        self.assertFalse(is_mutation("t3_thread_configure", {"threadId": "t"}))

    def test_project_pagination_and_thread_read_use_native_tools(self):
        from t3_backend import T3Backend

        calls = []

        class Native:
            def call(self, name, args, key=None):
                calls.append((name, args))
                if name == "t3_project_list":
                    return {
                        "projects": [{"id": str(args.get("cursor", 0))}],
                        "nextCursor": 1 if "cursor" not in args else None,
                    }
                return {
                    "thread": {"status": "running", "pullRequests": []},
                    "recentRuns": [{"runId": "run", "ordinal": 1, "status": "running"}],
                    "items": [],
                }

        backend = T3Backend(
            Native(), lambda *a, **k: self.fail("No internal read fallback")
        )
        self.assertEqual(
            len(
                backend("orchestration.subscribeShell", {}, first=True)["snapshot"][
                    "projects"
                ]
            ),
            2,
        )
        result = backend(
            "orchestration.getThreadProjection", {"threadId": "mcp:actual"}
        )
        self.assertEqual(result["runs"][0]["id"], "run")
        self.assertEqual(calls[-1][0], "t3_thread_read")


class PersistenceTests(unittest.TestCase):
    def test_lost_response_reuses_client_id_and_blocks_uncertain_new_login(self):
        from t3_mcp import NativeMcp
        from dispatch_store import Store

        with tempfile.TemporaryDirectory() as directory:
            store = Store(Path(directory) / "db")
            auth = type(
                "Auth",
                (),
                {
                    "credentials": lambda self: {
                        "access_token": "private",
                        "generation": "one",
                    }
                },
            )()
            client = NativeMcp({"baseUrl": "http://127.0.0.1:8501"}, auth, store)
            calls = []

            def request(method, params):
                calls.append((method, params))
                if len(calls) == 1:
                    raise TimeoutError("Lost reply")
                return {"structuredContent": {"threadId": "actual"}, "content": []}

            client.request = request
            args = {"clientRequestId": "stable", "title": "Fix"}
            with self.assertRaises(TimeoutError):
                client.call("t3_thread_launch", args, key="stable")
            auth.credentials = lambda: {
                "access_token": "private-2",
                "generation": "two",
            }
            with self.assertRaisesRegex(ValueError, "uncertain"):
                client.call("t3_thread_launch", args, key="stable")
            auth.credentials = lambda: {"access_token": "private", "generation": "one"}
            self.assertEqual(
                client.call("t3_thread_launch", args, key="stable")["threadId"],
                "actual",
            )
            self.assertEqual(calls[0], calls[1])
            self.assertEqual(
                client.call("t3_thread_launch", args, key="stable")["threadId"],
                "actual",
            )
            self.assertEqual(len(calls), 2)


class ReadBoundaryTests(unittest.TestCase):
    def test_native_read_reaches_latest_reply_and_preserves_user_questions(self):
        from t3_backend import T3Backend

        pending = [0]

        class Native:
            def call(self, name, args, key=None):
                if name == "t3_thread_configure":
                    return {
                        "modelSelection": {
                            "instanceId": "codex",
                            "model": "sol",
                            "options": [],
                        }
                    }
                next_page = "afterPosition" in args
                return {
                    "thread": {"status": "waiting", "pendingRequestCount": pending[0]},
                    "recentRuns": [{"runId": "new", "ordinal": 2, "status": "waiting"}],
                    "items": [
                        {
                            "type": "assistant_message",
                            "runId": "new" if next_page else "old",
                            "status": "completed",
                            "text": "Need your choice" if next_page else "Old result",
                        }
                    ],
                    "hasMore": not next_page,
                    "nextPosition": 1 if next_page else 0,
                }

        backend = T3Backend(Native(), None)
        result = backend("orchestration.getThreadProjection", {"threadId": "owned"})
        self.assertEqual(
            result["messages"], [{"role": "assistant", "text": "Need your choice"}]
        )
        self.assertTrue(result["quota_recovery_eligible"])
        pending[0] = 1
        self.assertFalse(
            backend("orchestration.getThreadProjection", {"threadId": "owned"})[
                "quota_recovery_eligible"
            ]
        )

    def test_quota_handoff_configures_native_model_before_queued_send(self):
        from t3_backend import T3Backend

        calls = []

        selection = {
            "instanceId": "claudeAgent",
            "model": "sonnet",
            "options": [{"id": "effort", "value": "medium"}],
        }

        class Native:
            def call(self, name, args, key=None):
                calls.append((name, args, key))
                if name == "t3_thread_configure" and "modelSelection" not in args:
                    return {"modelSelection": selection}
                return {}

        backend = T3Backend(Native(), None)
        backend(
            "orchestration.dispatchCommand",
            {
                "type": "message.dispatch",
                "threadId": "owned",
                "commandId": "stable",
                "text": "Continue",
                "modelSelection": selection,
            },
        )
        self.assertEqual(
            [name for name, args, key in calls],
            ["t3_thread_configure", "t3_thread_configure", "t3_thread_send"],
        )
        self.assertEqual(calls[0][1]["modelSelection"], selection)
        self.assertNotIn("modelSelection", calls[1][1], "read back, not assumed")
        self.assertEqual(calls[2][1]["mode"], "queue")
        self.assertEqual(calls[2][1]["clientRequestId"], "stable")
        self.assertEqual(calls[2][1]["threadId"], "owned")
