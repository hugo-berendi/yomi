"""Two parallel topics stay apart: roots, notices, wakes and the Hermes session keys."""

import asyncio
import ast
import os
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from ciel_watch import deliver
from matrix_threads import open_and_wait
from test_notices import BOT, OWNER, ROOM, FakeAdapter
from test_support import FakeT3, Workspace, make_dispatcher, start

OTHER = "!" + "b" * 43
SOURCE = os.environ.get("CIEL_HERMES_SOURCE")


class ThreadAdapter(FakeAdapter):
    """create_handoff_thread as the Hermes Matrix adapter does it: post a seed, return its event ID."""

    def __init__(self, members):
        super().__init__(members)
        self.roots = []

    async def create_handoff_thread(self, room, title):
        self.roots.append((room, title))
        return f"$root{len(self.roots)}"


class ThreadTests(unittest.TestCase):
    def setUp(self):
        self.work = Workspace().__enter__()
        self.addCleanup(self.work.__exit__)
        self.d = make_dispatcher(
            self.work.db(), FakeT3(), rooms=lambda config, room: room or ROOM
        )
        self.call = lambda path, op, args=None: self.d.handle(op, args or {})
        self.adapter = ThreadAdapter({ROOM: [OWNER, BOT], OTHER: [OWNER, BOT]})
        self.woken = []

    def deliver(self):
        async def inline(function, *args):
            return function(*args)

        async def wake(adapter, room, owner, text, thread_root=None):
            self.woken.append((room, thread_root, text))

        with patch("ciel_watch.asyncio.to_thread", inline):
            asyncio.run(
                deliver(self.adapter, "unused", OWNER, call=self.call, wake=wake)
            )

    def open(self, key, title):
        self.d.handle("thread_open", {"thread_key": key, "title": title})

    def test_each_topic_gets_its_own_root_and_events_return_to_it(self):
        self.open("monitor", "Monitoring: Backup")
        self.open("fix", "Fix: Login")
        self.assertEqual(
            self.d.handle("thread_status", {"thread_key": "fix"})["state"], "pending"
        )
        self.deliver()
        self.deliver()
        self.assertEqual(
            self.adapter.roots,
            [(ROOM, "Monitoring: Backup"), (ROOM, "Fix: Login")],
            "posted once each, in the owner DM only",
        )
        start(self.d, "a", room_id=ROOM, thread_key="monitor")
        start(self.d, "b", room_id=ROOM, thread_key="fix")
        start(self.d, "c", room_id=ROOM)
        for key, text in (
            ("a", "Alpha fertig"),
            ("b", "Beta fertig"),
            ("c", "Gamma fertig"),
        ):
            self.d.store.notify(self.d.store.task(key), "e" + key, text)
        self.deliver()
        by_text = {
            t.split("\n")[1].split(" ")[0]: (r, root)
            for r, root, t in self.woken
            if "fertig" in t
        }
        self.assertEqual(by_text["Alpha"], (ROOM, "$root1"))
        self.assertEqual(by_text["Beta"], (ROOM, "$root2"))
        self.assertEqual(by_text["Gamma"], (ROOM, None), "main chat stays threadless")

    def test_text_fallback_posts_into_the_thread_only(self):
        self.open("monitor", "Monitoring")
        self.deliver()
        start(self.d, "a", room_id=ROOM, thread_key="monitor")
        self.d.store.notify(self.d.store.task("a"), "e", "Hallo")
        self.d.store.db.execute("UPDATE notices SET wake_failed_since=0")
        self.deliver()
        self.assertEqual(self.adapter.sent, [(ROOM, "Hallo", {"thread_id": "$root1"})])

    def test_unknown_or_foreign_thread_keys_are_refused(self):
        with self.assertRaises(ValueError):
            start(self.d, "a", room_id=ROOM, thread_key="nope")
        self.open("monitor", "M")
        with self.assertRaisesRegex(ValueError, "noch nicht angelegt"):
            start(self.d, "a", room_id=ROOM, thread_key="monitor")
        self.deliver()
        with self.assertRaisesRegex(ValueError, "anderen Raum"):
            start(self.d, "b", room_id=OTHER, thread_key="monitor")
        with self.assertRaisesRegex(ValueError, "anderen Raum"):
            self.d.handle(
                "thread_open", {"thread_key": "monitor", "title": "M", "room_id": OTHER}
            )

    def test_event_ids_come_only_from_the_gateway_format(self):
        self.open("monitor", "M")
        with self.assertRaises(ValueError):
            self.d.handle(
                "thread_created", {"thread_key": "monitor", "event_id": "!room:x"}
            )

    def test_third_member_room_gets_no_thread_root(self):
        self.adapter = ThreadAdapter({ROOM: [OWNER, BOT, "@x:example.org"]})
        self.open("monitor", "M")
        self.deliver()
        self.assertEqual(self.adapter.roots, [])

    def test_tool_waits_for_the_gateway_then_reports_open(self):
        states = iter(
            [{"state": "pending", "thread_key": "k"}] * 2
            + [{"state": "open", "thread_key": "k"}]
        )
        calls = []

        def call(op, args):
            calls.append(op)
            return next(states)

        result = open_and_wait(
            call, {"thread_key": "k", "title": "T"}, sleep=lambda s: None
        )
        self.assertEqual(result["state"], "open")
        self.assertEqual(calls, ["thread_open", "thread_status", "thread_status"])


@unittest.skipUnless(SOURCE, "Requires built Hermes source")
class HermesThreadContractTests(unittest.TestCase):
    """What the pinned Hermes does with a thread source, from its own code."""

    def setUp(self):
        import sys

        sys.path.insert(0, SOURCE)
        self.addCleanup(sys.path.remove, SOURCE)

    def source(self, thread=None):
        from gateway.config import Platform
        from gateway.session import SessionSource

        return SessionSource(
            platform=Platform.MATRIX,
            chat_id=ROOM,
            chat_type="dm",
            user_id=OWNER,
            thread_id=thread,
        )

    def test_session_key_includes_the_thread_for_dms(self):
        # The build's test runner has no Hermes dependencies, so the key layout
        # is pinned from source; the behavioural test below runs where they exist.
        body = (Path(SOURCE) / "gateway/session.py").read_text()
        self.assertIn("thread_part = [thread_id] if thread_id else []", body)
        self.assertIn("parts += user_part + thread_part if is_dm", body)

    def test_threads_and_main_chat_have_distinct_sessions(self):
        try:
            from gateway.session import build_session_key
        except ImportError as exc:
            self.skipTest(f"Hermes dependencies unavailable: {exc.name}")

        keys = {build_session_key(self.source(t)) for t in (None, "$root1", "$root2")}
        self.assertEqual(len(keys), 3)
        self.assertEqual(
            build_session_key(self.source("$root1")),
            build_session_key(self.source("$root1")),
        )

    def test_outbound_relation_is_a_real_m_thread(self):
        text = (
            Path(SOURCE) / "../../../share/hermes/plugins/platforms/matrix/adapter.py"
        ).read_text()
        tree = ast.parse(text)
        fn = next(
            n
            for n in ast.walk(tree)
            if isinstance(n, ast.FunctionDef) and n.name == "_apply_relation_metadata"
        )
        fn.returns = None
        for arg in fn.args.args + fn.args.kwonlyargs:
            arg.annotation = None
        scope = {}
        exec(compile(ast.Module([fn], []), "upstream", "exec"), scope)
        content = {}
        scope["_apply_relation_metadata"](
            SimpleNamespace(), content, metadata={"thread_id": "$root1"}
        )
        self.assertEqual(content["m.relates_to"]["rel_type"], "m.thread")
        self.assertEqual(content["m.relates_to"]["event_id"], "$root1")
        self.assertEqual(
            content["m.relates_to"]["m.in_reply_to"], {"event_id": "$root1"}
        )


if __name__ == "__main__":
    unittest.main()
