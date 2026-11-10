"""Exercise the owner gate without Matrix credentials or model calls."""

import asyncio
import unittest
from types import SimpleNamespace

from runtime_approvals import ApprovalBridge

# Compile the installed consumer methods, keeping optional Hermes dependencies
# outside the test. This executes their bodies, including their real imports.
import ast
import logging
import os
from pathlib import Path
import queue
import sys
import threading
from unittest.mock import patch

import runtime_approvals


class ApprovalTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.posts = []
        self.members = {"@hugo:test": {}, "@ciel:test": {}}

        async def members(room):
            return self.members

        async def send(room, text):
            self.posts.append((room, text))
            return SimpleNamespace(success=True, message_id=f"$prompt{len(self.posts)}")

        self.adapter = SimpleNamespace(
            _client=SimpleNamespace(mxid="@ciel:test", get_joined_members=members),
            send=send,
        )
        self.bridge = ApprovalBridge(self.adapter, "@hugo:test")

    async def pending(self, timeout=1):
        task = asyncio.create_task(
            self.bridge.ask("!dm:test", "Thread anlegen", timeout)
        )
        await asyncio.sleep(0)
        return task

    async def test_only_owner_can_accept_exact_open_prompt_once(self):
        task = await self.pending()
        for room, event, sender in [
            ("!other:test", "$prompt1", "@hugo:test"),
            ("!dm:test", "$old", "@hugo:test"),
            ("!dm:test", "$prompt1", "@foreign:test"),
        ]:
            await self.bridge.answer(room, event, "✅", sender)
            self.assertFalse(task.done())
        await self.bridge.answer("!dm:test", "$prompt1", "✅", "@hugo:test")
        self.assertTrue(await task)
        self.assertFalse(
            await self.bridge.answer("!dm:test", "$prompt1", "✅", "@hugo:test")
        )

    async def test_denial_timeout_restart_and_changed_membership_fail_closed(self):
        task = await self.pending()
        await self.bridge.answer("!dm:test", "$prompt1", "❌", "@hugo:test")
        self.assertFalse(await task)
        self.assertFalse(await self.bridge.ask("!dm:test", "Thread", 0.001))
        task = await self.pending()
        self.bridge.close()
        self.assertFalse(await task)
        replacement = ApprovalBridge(self.adapter, "@hugo:test")
        self.assertFalse(
            await replacement.answer("!dm:test", "$prompt3", "✅", "@hugo:test")
        )
        self.members["@foreign:test"] = {}
        self.assertFalse(await replacement.ask("!dm:test", "Thread", 1))


def consumer(path, cls, name):
    tree = ast.parse(path.read_text())
    klass = next(n for n in tree.body if isinstance(n, ast.ClassDef) and n.name == cls)
    method = next(
        n
        for n in klass.body
        if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef)) and n.name == name
    )
    module = ast.Module(
        body=[
            ast.ImportFrom(
                module="__future__", names=[ast.alias(name="annotations")], level=0
            ),
            method,
        ],
        type_ignores=[],
    )
    namespace = {
        "logger": logging.getLogger(__name__),
        "HERMES_TOOLS_MCP_SERVER_NAME": "hermes-tools",
    }
    exec(compile(ast.fix_missing_locations(module), str(path), "exec"), namespace)
    return namespace[name]


@unittest.skipUnless(
    os.environ.get("CIEL_HERMES_SOURCE"), "Requires built Hermes consumer"
)
class ConsumerTests(ApprovalTests):
    async def asyncSetUp(self):
        await super().asyncSetUp()
        root = Path(os.environ["CIEL_HERMES_SOURCE"])
        adapter_path = root / "plugins/platforms/matrix/adapter.py"
        if not adapter_path.exists():
            adapter_path = (
                root / "../../../share/hermes/plugins/platforms/matrix/adapter.py"
            )
        self.handle = consumer(
            root / "agent/transports/codex_app_server_session.py",
            "CodexAppServerSession",
            "_handle_server_request",
        )
        self.on_reaction = consumer(
            adapter_path,
            "MatrixAdapter",
            "_on_reaction",
        )
        self.dispatch = consumer(
            root / "agent/transports/codex_app_server.py",
            "CodexAppServerClient",
            "_dispatch",
        )
        self.env = {
            "HERMES_SESSION_PLATFORM": "matrix",
            "HERMES_SESSION_CHAT_TYPE": "dm",
            "HERMES_SESSION_USER_ID": "@hugo:test",
            "HERMES_SESSION_CHAT_ID": "!dm:test",
        }
        self.modules = patch.dict(
            sys.modules,
            {
                "agent.runtime_approvals": runtime_approvals,
                "agent.redact": SimpleNamespace(
                    redact_sensitive_text=lambda text, **kwargs: text
                ),
                "gateway.session_context": SimpleNamespace(
                    get_session_env=lambda key, default: self.env.get(key, default)
                ),
            },
        )
        self.modules.start()
        self.environment = patch.dict(
            os.environ, {"MATRIX_ALLOWED_USERS": "@hugo:test"}
        )
        self.environment.start()
        self.addCleanup(self.modules.stop)
        self.addCleanup(self.environment.stop)
        runtime_approvals.connect(self.adapter)
        self.addCleanup(runtime_approvals.disconnect, self.adapter)
        self.responses = []
        self.client = SimpleNamespace(
            respond=lambda rid, result: self.responses.append((rid, result)),
            is_alive=lambda: True,
            _notifications=queue.Queue(),
            _server_requests=queue.Queue(),
        )
        self.session = SimpleNamespace(
            _client=self.client,
            _thread_id="thread-1",
            _active_turn_id="turn-1",
            _closed=False,
            _interrupt_event=threading.Event(),
        )
        self.session._SERVER_REQUEST_HANDLERS = {
            "mcpServer/elicitation/request": consumer(
                root / "agent/transports/codex_app_server_session.py",
                "CodexAppServerSession",
                "_respond_elicitation",
            )
        }
        self.request = {
            "id": 7,
            "method": "mcpServer/elicitation/request",
            "params": {
                "threadId": "thread-1",
                "turnId": "turn-1",
                "serverName": "ciel",
                "mode": "form",
                "requestedSchema": {"type": "object", "properties": {}},
                "_meta": {
                    "codex_approval_kind": "mcp_tool_call",
                    "tool_name": "ciel_thread_open",
                    "tool_params": {"title": "Test"},
                },
            },
        }
        self.adapter._is_self_sender = lambda sender: sender == "@ciel:test"
        self.adapter._is_duplicate_event = lambda event: False

        async def unrelated(*args):
            return False

        self.adapter._handle_approval_reaction = unrelated
        self.adapter._handle_model_picker_reaction = unrelated
        self.adapter._handle_choice_picker_reaction = unrelated

    async def start_request(self):
        task = asyncio.create_task(
            asyncio.to_thread(self.handle, self.session, self.request)
        )
        for _ in range(100):
            if runtime_approvals._bridge.pending:
                return task
            await asyncio.sleep(0.005)
        self.fail("The actual consumer did not publish an approval")

    async def react(self, sender="@hugo:test", key="✅"):
        await self.on_reaction(
            self.adapter,
            SimpleNamespace(
                sender=sender,
                event_id="$reaction",
                room_id="!dm:test",
                content={"m.relates_to": {"event_id": "$prompt1", "key": key}},
            ),
        )

    async def test_actual_consumer_returns_one_accept_on_exact_rpc_id(self):
        task = await self.start_request()
        await self.react(sender="@foreign:test")
        self.assertEqual(self.responses, [])
        await self.react()
        await task
        self.assertEqual(
            self.responses, [(7, {"action": "accept", "content": None, "_meta": None})]
        )
        await self.react()
        await asyncio.to_thread(self.handle, self.session, self.request)
        self.assertEqual(len(self.responses), 1)

    async def test_resolved_runtime_request_cannot_be_accepted(self):
        task = await self.start_request()
        note = {
            "method": "serverRequest/resolved",
            "params": {"threadId": "thread-1", "requestId": 7},
        }
        self.dispatch(self.client, note)
        self.assertEqual(self.client._notifications.get_nowait(), note)
        await self.react()
        await task
        self.assertEqual(self.responses[0][1]["action"], "decline")

    async def test_foreign_turn_and_wrong_owner_context_decline_without_prompt(self):
        for key, value in [("turnId", "old-turn"), ("serverName", "other")]:
            with patch.dict(self.request["params"], {key: value}):
                self.session._ciel_approval_seen = set()
                await asyncio.to_thread(self.handle, self.session, self.request)
                self.assertEqual(self.responses[-1][1]["action"], "decline")
        self.env["HERMES_SESSION_USER_ID"] = "@foreign:test"
        self.session._ciel_approval_seen = set()
        await asyncio.to_thread(self.handle, self.session, self.request)
        self.assertEqual(self.responses[-1][1]["action"], "decline")
        self.assertEqual(self.posts, [])

    async def test_interrupt_and_disconnect_do_not_accept(self):
        task = await self.start_request()
        self.session._interrupt_event.set()
        await self.react()
        await task
        self.assertEqual(self.responses[-1][1]["action"], "decline")

    async def test_accept_followed_by_adapter_replacement_declines(self):
        # Model the exact race between future.result and the final validity check.
        def submitted(coroutine, loop):
            coroutine.close()

            def result(timeout):
                runtime_approvals._bridge.close()
                return True

            return SimpleNamespace(result=result, cancel=lambda: None)

        with patch.object(asyncio, "run_coroutine_threadsafe", submitted):
            await asyncio.to_thread(self.handle, self.session, self.request)
        self.assertEqual(self.responses[-1][1]["action"], "decline")

    async def test_no_owner_response_returns_decline_to_runtime(self):
        with patch.object(runtime_approvals, "TIMEOUT", 0.02):
            await asyncio.to_thread(self.handle, self.session, self.request)
        self.assertEqual(
            self.responses, [(7, {"action": "decline", "content": None, "_meta": None})]
        )

    async def test_owner_denial_returns_decline_to_runtime(self):
        task = await self.start_request()
        await self.react(key="❌")
        await task
        self.assertEqual(self.responses[-1][1]["action"], "decline")

    async def test_completed_turn_invalidates_approval(self):
        task = await self.start_request()
        self.dispatch(
            self.client,
            {
                "method": "turn/completed",
                "params": {"threadId": "thread-1", "turn": {"id": "turn-1"}},
            },
        )
        await self.react()
        await task
        self.assertEqual(self.responses[-1][1]["action"], "decline")


if __name__ == "__main__":
    unittest.main()
