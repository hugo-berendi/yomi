"""Owner-DM notices: one per event, evidence included, delivered only to the owner-only room."""

import asyncio
import time
import unittest
from types import SimpleNamespace
from unittest.mock import patch

from ciel_watch import deliver
from mcp_server import OPERATIONS, TOOLS
from test_support import Clock, FakeT3, Workspace, make_dispatcher, start

OWNER, BOT = "@hugo:example.org", "@ciel:example.org"
ROOM = "!" + "a" * 43  # room v12 identifiers carry no server name


class NoticeTests(unittest.TestCase):
    def setUp(self):
        self.work = Workspace().__enter__()
        self.addCleanup(self.work.__exit__)
        self.t3, self.clock = FakeT3(), Clock()
        patcher = patch.object(time, "time", self.clock)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.d = make_dispatcher(self.work.db(), self.t3)

    def bodies(self):
        return [n["body"] for n in self.work.notices(self.d)]

    def test_ready_notice_carries_pr_head_and_says_what_was_checked(self):
        start(self.d, "a", room_id=ROOM)
        self.t3.green_pr("thread-1")
        self.t3.finish("thread-1")
        for _ in range(3):
            self.d.tick()
        ended, notice = self.work.notices(self.d)
        self.assertIn("PR-Prüfung steht aus", ended["body"])
        self.assertNotIn("grün", ended["body"].replace("nicht grün", ""))
        self.assertEqual(notice["room_id"], ROOM)
        self.assertIn("abc123", notice["body"])
        self.assertIn("https://github.com/o/r/pull/1", notice["body"])
        self.assertIn("noch nicht gemergt", notice["body"])
        self.assertIn("Geprüfter Head: abc123", notice["body"])
        # Plain text for the chat: no JSON dump of the verdict.
        self.assertNotIn("{", notice["body"])

    def test_completed_run_without_ci_is_not_called_a_result(self):
        start(self.d, "a")
        self.t3.green_pr("thread-1")
        self.t3.pull_requests["detail"]["checks"] = []
        self.t3.finish("thread-1")
        self.d.tick()
        ended, body = self.bodies()
        self.assertIn("PR-Prüfung steht aus", ended)
        self.assertIn("Hugos Entscheidung ist nötig", body)
        self.assertIn(
            "Noch offen: PR/CI konnte nicht unabhängig bestätigt werden", body
        )
        self.assertIn("unbestätigt", body)

    def test_failure_and_blocked_states_notify_once_without_progress_chatter(self):
        start(self.d, "a"), start(self.d, "b")
        self.t3.threads["thread-1"]["runs"] = [self.t3.run(1, "waiting", "thread-1")]
        self.t3.threads["thread-2"]["runs"] = [self.t3.run(1, "failed", "thread-2")]
        for _ in range(4):
            self.d.tick()
        self.assertEqual(len(self.bodies()), 2)
        # A run-level wait is an approval: named, never granted by Ciel.
        self.assertTrue(any("Freigabe in T3" in b for b in self.bodies()))
        self.assertTrue(any("fehlgeschlagen" in b for b in self.bodies()))
        # A running agent produces no notice, whatever its token or tool activity.
        start(self.d, "c")
        for _ in range(3):
            self.d.tick()
        self.assertEqual(len(self.bodies()), 2)

    def test_notice_dedup_is_enforced_by_the_database(self):
        start(self.d, "a")
        task = self.d.store.task("a")
        self.assertTrue(self.d.store.notify(task, "same-event", "first"))
        self.assertFalse(self.d.store.notify(task, "same-event", "second"))
        self.assertEqual(self.bodies(), ["first"])

    def test_reading_notices_is_passive_and_ack_is_idempotent(self):
        start(self.d, "a")
        self.t3.threads["thread-1"]["runs"] = [self.t3.run(1, "failed", "thread-1")]
        self.d.tick()
        calls = len(self.t3.calls)
        (notice,) = self.d.handle("notices", {})
        self.assertEqual(
            len(self.t3.calls), calls, "the watcher must not trigger T3 reads"
        )
        (
            self.d.handle("ack", {"id": notice["id"]}),
            self.d.handle("ack", {"id": notice["id"]}),
        )
        self.assertEqual(self.d.handle("notices", {}), [])

    def test_explicit_domainless_room_id_is_stored_and_used_for_delivery(self):
        summary = start(self.d, "a", room_id=ROOM)
        self.assertEqual(self.d.store.task("a")["room_id"], ROOM)
        self.assertEqual(summary["task_key"], "a")

    def test_a_room_that_fails_verification_queues_nothing(self):
        def refuse(config, room):
            raise ValueError("Could not verify the private Matrix room")

        d = make_dispatcher(self.work.db(), self.t3, rooms=refuse)
        with self.assertRaises(ValueError):
            start(d, "a", room_id="!stranger")
        self.assertEqual(d.tasks(), [])
        d = make_dispatcher(self.work.db(), self.t3, rooms=lambda config, room: None)
        with self.assertRaisesRegex(ValueError, "room ID is required"):
            start(d, "a")

    def test_ciel_tasks_is_a_read_only_inspection_tool(self):
        tool = next(t for t in TOOLS if t["name"] == "ciel_tasks")
        self.assertTrue(tool["annotations"]["readOnlyHint"])
        self.assertEqual(OPERATIONS["ciel_tasks"], "tasks")
        props = next(t for t in TOOLS if t["name"] == "ciel_start_task")["inputSchema"][
            "properties"
        ]
        self.assertIn("depends_on", props)
        start(self.d, "a"), start(self.d, "b"), start(self.d, "c")
        view = self.d.handle("tasks", {})
        self.assertEqual(view["slots"], {"used": 2, "limit": 2})
        self.assertEqual([t["task_key"] for t in view["tasks"]], ["a", "b", "c"])
        self.assertEqual(view["tasks"][2]["waiting_on"]["kind"], "slot")


class FakeClient:
    def __init__(self, members):
        self.members, self.mxid = members, BOT

    async def get_joined_members(self, room):
        return SimpleNamespace(joined={m: {} for m in self.members[room]})


class FakeAdapter:
    def __init__(self, members, fail=False):
        self._client, self.sent, self.fail = FakeClient(members), [], fail
        self.woken = []

    async def send(self, room, body):
        self.sent.append((room, body))
        return SimpleNamespace(success=not self.fail)


class DeliveryTests(unittest.TestCase):
    def setUp(self):
        self.work = Workspace().__enter__()
        self.addCleanup(self.work.__exit__)
        self.t3 = FakeT3()
        self.d = make_dispatcher(
            self.work.db(), self.t3, rooms=lambda config, room: room
        )
        self.call = lambda path, operation, args=None: self.d.handle(
            operation, args or {}
        )

    def queue(self, room):
        start(self.d, "a", room_id=room)
        task = self.d.store.task("a")
        self.d.store.notify(task, "e1", "Auftrag fertig")

    def run_delivery(self, adapter, wake_fails=False):
        async def inline(
            function, *args
        ):  # the test broker's SQLite handle is single-threaded
            return function(*args)

        async def wake(adapter, room, owner, text):
            if wake_fails:
                raise RuntimeError("internal wake not accepted by adapter")
            adapter.woken.append((room, owner, text))

        with patch("ciel_watch.asyncio.to_thread", inline):
            asyncio.run(deliver(adapter, "unused", OWNER, call=self.call, wake=wake))

    def test_events_wake_ciel_once_and_never_post_raw_text(self):
        self.queue(ROOM)
        adapter = FakeAdapter({ROOM: [OWNER, BOT]})
        self.run_delivery(adapter), self.run_delivery(adapter)
        self.assertEqual(adapter.sent, [], "Ciel answers in her own words")
        ((room, owner, text),) = adapter.woken
        self.assertEqual((room, owner), (ROOM, OWNER))
        self.assertIn("Auftrag fertig", text)
        self.assertIn("nicht von Hugo", text)
        self.assertIn("keine Anweisungen", text)

    def test_unadmitted_wake_falls_back_to_plain_text_for_hugo(self):
        self.queue(ROOM)
        adapter = FakeAdapter({ROOM: [OWNER, BOT]})
        with patch.object(time, "time", lambda: 1000.0):
            self.run_delivery(adapter, wake_fails=True)
            self.run_delivery(adapter, wake_fails=True)
        self.assertEqual(adapter.sent, [])
        (pending,) = self.d.handle("notices", {})
        self.assertEqual(pending["mode"], "text")
        self.run_delivery(adapter, wake_fails=True)
        self.assertEqual(adapter.sent, [(ROOM, "Auftrag fertig")])
        self.assertEqual(self.d.handle("notices", {}), [])

    def test_failed_text_send_stays_pending_and_is_retried(self):
        self.queue(ROOM)
        self.d.store.db.execute("UPDATE notices SET wake_failed_since=0")
        adapter = FakeAdapter({ROOM: [OWNER, BOT]}, fail=True)
        self.run_delivery(adapter)
        self.assertEqual(len(self.d.handle("notices", {})), 1)
        adapter.fail = False
        self.run_delivery(adapter)
        self.assertEqual(self.d.handle("notices", {}), [])

    def test_room_with_a_third_member_receives_nothing(self):
        self.queue(ROOM)
        adapter = FakeAdapter({ROOM: [OWNER, BOT, "@welles:example.org"]})
        self.run_delivery(adapter)
        self.assertEqual(adapter.sent, [])
        self.assertEqual(len(self.d.handle("notices", {})), 1, "withheld, not dropped")

    def test_room_without_the_owner_receives_nothing(self):
        self.queue(ROOM)
        adapter = FakeAdapter({ROOM: ["@someone:example.org", BOT]})
        self.run_delivery(adapter)
        self.assertEqual(adapter.sent, [])


if __name__ == "__main__":
    unittest.main()
