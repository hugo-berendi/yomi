"""Event delivery speed and the read-only task intent.

Timing uses a fake clock and an in-memory T3. The cadence constants are checked
against that clock; nothing here launches a model run or measures a live host.
"""

import asyncio
import json
import threading
import time
import unittest
from types import SimpleNamespace
from unittest.mock import patch

import ciel_watch
from mcp_server import TOOLS
from pr_verification import AsyncVerifier
from task_scheduler import ACTIVE_POLL, TICK
from test_support import Clock, FakeT3, Workspace, make_dispatcher, start

READONLY = {"intent": "readonly_test"}


class Case(unittest.TestCase):
    def setUp(self):
        self.work = Workspace().__enter__()
        self.addCleanup(self.work.__exit__)
        self.t3, self.clock = FakeT3(), Clock()
        patcher = patch.object(time, "time", self.clock)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.d = make_dispatcher(self.work.db(), self.t3)

    def bodies(self, d=None):
        return [n["body"] for n in self.work.notices(d or self.d)]

    def dispatched(self, kind="message.dispatch"):
        return [c for c in self.t3.dispatched if c["type"] == kind]

    def seconds_until(self, wanted, limit=120):
        """Fake seconds of paced ticks until `wanted()` holds."""
        for elapsed in range(0, limit, TICK):
            self.d.tick(paced=True)
            if wanted():
                return elapsed
            self.clock.advance(TICK)
        self.fail("not observed within %ss" % limit)


class ReadonlyIntentTests(Case):
    def test_finished_readonly_task_ends_without_pr_verification_or_repair(self):
        start(self.d, "a", **READONLY)
        self.t3.finish("thread-1", reply="Gelesen: alles wie erwartet")
        for _ in range(5):
            self.d.tick()
            self.clock.advance(60)
        row = self.d.store.task("a")
        self.assertEqual(row["last_status"], "completed")
        self.assertEqual(self.d.summary(row)["verification"]["state"], "not_required")
        self.assertEqual(self.dispatched(), [], "no repair follow-up for a no-PR task")
        self.assertFalse([c for c in self.t3.calls if c.startswith("pullRequests")])
        (body,) = self.bodies()
        self.assertIn("Nur-Lesen-Test", body)
        self.assertIn("nichts davon geprüft", body)
        self.assertIn("unbestätigt", body)
        for word in ("grün", "gelöst", "gemergt"):
            self.assertNotIn(word, body.replace("nicht grün", ""))

    def test_readonly_task_that_still_opened_a_pr_gets_no_forge_claim(self):
        start(self.d, "a", **READONLY)
        self.t3.green_pr("thread-1")
        self.t3.finish("thread-1")
        self.d.tick()
        (body,) = self.bodies()
        self.assertIn("PR: https://github.com/o/r/pull/1", body)
        self.assertFalse([c for c in self.t3.calls if c.startswith("pullRequests")])
        self.assertNotIn("Geprüfter Head", body)

    def test_implementation_without_pr_is_still_repaired_and_never_called_done(self):
        start(self.d, "a")
        self.t3.finish("thread-1")
        self.d.tick()
        (followup,) = self.dispatched()
        self.assertIn("Independent PR verification found", followup["text"])
        self.assertEqual(self.d.store.task("a")["intent"], "implementation_pr")

    def test_intent_is_stated_not_inferred_and_validated(self):
        d = self.d
        start(d, "plain")
        d.start(
            {
                "task_key": "wording",
                "project_id": "allowed",
                "description": "Das ist ein Test: keine Commits, kein PR, nur lesen",
                "room_id": "!room",
            }
        )
        self.assertEqual(d.store.task("wording")["intent"], "implementation_pr")
        with self.assertRaisesRegex(ValueError, "intent"):
            start(d, "bad", intent="no_pr")
        self.assertEqual(
            d.summary(d.store.task("plain"))["intent"], "implementation_pr"
        )

    def test_readonly_prompt_has_no_pr_boilerplate_but_keeps_the_limits(self):
        start(self.d, "r", **READONLY)
        start(self.d, "i")
        prompts = {
            k: self.t3.launches[i]["initialMessage"]["text"]
            for i, k in enumerate(["r", "i"])
        }
        for phrase in ("reviewable PR", "exactly that SHA", "screenshots", "Watch CI"):
            self.assertNotIn(phrase, prompts["r"])
            self.assertIn(phrase, prompts["i"])
        self.assertIn("do not edit files, commit, push", prompts["r"])
        self.assertIn("<user_task>\nDo r\n</user_task>", prompts["r"])

    def test_queued_readonly_task_keeps_its_intent_when_the_prompt_is_rebuilt(self):
        d = make_dispatcher(self.work.db(), self.t3, limit=1)
        start(d, "first")
        start(d, "queued", **READONLY)
        self.t3.finish("thread-1")
        self.t3.green_pr("thread-1")
        d.store.db.execute(
            "UPDATE tasks SET last_status='merged' WHERE task_key='first'"
        )
        d.store.db.commit()
        d.tick()
        self.assertNotIn(
            "reviewable PR", self.t3.launches[-1]["initialMessage"]["text"]
        )

    def test_row_from_before_the_column_counts_as_implementation(self):
        self.d.store.db.execute(
            "INSERT INTO tasks(task_key,payload,room_id,last_status) VALUES('old','{}','!r','running')"
        )
        self.assertEqual(self.d.store.task("old")["intent"], "implementation_pr")

    def test_solve_refuses_a_readonly_task_and_mcp_exposes_the_intent(self):
        start(self.d, "a", **READONLY)
        result = self.d.handle("solve", {"task_key": "a", "request_id": "s1"})
        self.assertFalse(result["solved"])
        schema = next(t for t in TOOLS if t["name"] == "ciel_start_task")["inputSchema"]
        self.assertEqual(
            schema["properties"]["intent"]["enum"],
            ["implementation_pr", "readonly_test"],
        )
        self.assertNotIn("intent", schema["required"])


class LifecycleSignalTests(Case):
    def test_run_end_is_announced_before_and_apart_from_the_verified_result(self):
        start(self.d, "a")
        self.t3.green_pr("thread-1")
        self.t3.finish("thread-1")
        self.d.tick()
        ended, verified = self.bodies()
        self.assertIn("Agent-Lauf beendet, PR-Prüfung steht aus", ended)
        self.assertIn("nicht grün", ended)
        self.assertNotIn("Geprüfter Head", ended)
        self.assertIn("Geprüfter Head: abc123", verified)
        # Repeated passes re-derive both events; neither is queued twice.
        for _ in range(3):
            self.clock.advance(400)
            self.d.tick()
        self.assertEqual(len(self.bodies()), 2)


class SlowForge:
    """Forge reads that block until released, as a hung forge would."""

    def __init__(self, inner):
        self.inner, self.release, self.started = (
            inner,
            threading.Event(),
            threading.Event(),
        )

    def __call__(self, operation, payload=None, **kwargs):
        self.started.set()
        self.release.wait(5)
        return self.inner(operation, payload)


class IndependentObservationTests(Case):
    def slow_dispatcher(self):
        slow = SlowForge(self.t3)
        verifier = AsyncVerifier(slow)
        self.addCleanup(verifier.executor.shutdown)
        self.addCleanup(slow.release.set)
        d = make_dispatcher(self.work.db(), self.t3)
        d.verifier = verifier
        self.d = d
        return slow

    def test_slow_forge_does_not_delay_another_tasks_question(self):
        slow = self.slow_dispatcher()
        start(self.d, "done"), start(self.d, "busy")
        self.t3.green_pr("thread-1")
        self.t3.finish("thread-1")
        self.d.tick()
        self.assertTrue(slow.started.wait(2))
        row = self.d.store.task("done")
        self.assertEqual(row["last_status"], "verifying")
        self.assertEqual(len(self.bodies()), 1, "run end announced while forge hangs")
        # The forge is still blocked; the other task's question must surface now.
        self.t3.ask("thread-2")
        self.clock.advance(ACTIVE_POLL)
        before = time.monotonic()
        self.d.tick(paced=True)
        self.assertLess(time.monotonic() - before, 1)
        self.assertTrue(any("Rückfrage" in b for b in self.bodies()))
        self.assertEqual(self.d.store.task("done")["last_status"], "verifying")
        slow.release.set()
        for _ in range(50):
            self.clock.advance(ACTIVE_POLL)
            self.d.tick(paced=True)
            if self.d.store.task("done")["last_status"] == "ready":
                break
            time.sleep(0.02)
        self.assertEqual(self.d.store.task("done")["last_status"], "ready")
        self.assertTrue(any("Geprüfter Head" in b for b in self.bodies()))

    def test_unreadable_forge_ends_unverified_not_green(self):
        class Broken:
            def __call__(self, *args, **kwargs):
                raise RuntimeError("forge down")

        verifier = AsyncVerifier(Broken())
        self.addCleanup(verifier.executor.shutdown)
        self.d.verifier = verifier
        start(self.d, "a")
        self.t3.green_pr("thread-1")
        self.t3.finish("thread-1")
        for _ in range(50):
            self.d.tick()
            self.clock.advance(ACTIVE_POLL)
            if self.d.store.task("a")["last_status"] == "needs_user":
                break
            time.sleep(0.02)
        self.assertEqual(self.d.store.task("a")["last_status"], "needs_user")
        self.assertEqual(
            json.loads(self.d.store.task("a")["verification"])["state"], "unverified"
        )

    def test_failing_task_does_not_hide_a_question_of_a_healthy_one(self):
        start(self.d, "bad"), start(self.d, "good")
        self.t3.broken.add("thread-1")
        self.t3.ask("thread-2")
        self.d.tick(paced=True)
        self.assertTrue(any("Rückfrage" in b for b in self.bodies()))
        self.assertEqual(self.d.store.task("bad")["failures"], 1)

    def test_question_is_seen_within_one_poll_not_thirty_seconds(self):
        start(self.d, "a")
        self.d.tick(paced=True)
        self.clock.advance(1)
        self.t3.ask("thread-1")
        waited = self.seconds_until(
            lambda: any("Rückfrage" in b for b in self.bodies())
        )
        self.assertLessEqual(waited, ACTIVE_POLL + TICK)

    def test_paced_ticks_bound_reads_per_task(self):
        start(self.d, "a")
        self.d.tick(paced=True)
        reads = self.t3.calls.count("orchestration.getThreadProjection")
        for _ in range(ACTIVE_POLL // TICK):
            self.clock.advance(TICK)
            self.d.tick(paced=True)
        self.assertEqual(
            self.t3.calls.count("orchestration.getThreadProjection"), reads
        )
        self.clock.advance(TICK)
        self.d.tick(paced=True)
        self.assertEqual(
            self.t3.calls.count("orchestration.getThreadProjection"), reads + 1
        )

    def test_woken_question_is_answered_on_the_same_run_after_a_restart(self):
        start(self.d, "a")
        self.t3.ask("thread-1")
        self.d.tick(paced=True)
        again = make_dispatcher(self.work.db(), self.t3)
        again.tick()
        self.assertEqual(
            len([b for b in self.bodies(again) if "Rückfrage" in b]), 1, "no repeat"
        )
        (listed,) = again.handle("requests", {})
        result = again.handle(
            "answer",
            {
                "task_key": "a",
                "request": listed["request"],
                "request_id": "r1",
                "answers": {"Welche Farbe?": "Grün"},
            },
        )
        self.assertTrue(
            result["accepted"] and result["same_run"] and result["continued"]
        )
        self.assertEqual(self.dispatched(), [], "an answer starts no new run")

    def test_stopped_task_stays_stopped_and_is_never_observed_or_answered(self):
        start(self.d, "a")
        self.d.tick()
        self.d.handle("stop", {"task_key": "a", "request_id": "s"})
        calls = len(self.t3.calls)
        self.t3.finish("thread-1")
        self.t3.ask("thread-1")
        for _ in range(3):
            self.clock.advance(60)
            self.d.tick(paced=True)
        self.assertEqual(self.d.store.task("a")["last_status"], "stopped")
        self.assertEqual(
            [c for c in self.t3.calls[calls:] if c.startswith("orchestration.get")], []
        )
        self.assertEqual(self.dispatched("message.dispatch"), [])


class WatcherTests(unittest.TestCase):
    def run_deliver(self, calls, notices, wake, withheld, members):
        adapter = SimpleNamespace(
            _client=SimpleNamespace(
                mxid="@ciel:x",
                get_joined_members=lambda room: asyncio.sleep(0, members),
            )
        )

        def call(path, operation, args=None):
            calls.append((operation, args))
            return notices if operation == "notices" else {}

        asyncio.run(
            ciel_watch.deliver(
                adapter, "sock", "@hugo:x", call=call, wake=wake, withheld=withheld
            )
        )

    def test_failed_wake_is_retried_slowly_and_a_foreign_room_is_not_asked_again(self):
        notice = {"id": 7, "room_id": "!r", "body": "b", "mode": "wake"}
        owner_room = {"@hugo:x": {}, "@ciel:x": {}}
        attempts, calls, withheld = [], [], {}

        async def failing(adapter, room, owner, text):
            attempts.append(text)
            raise RuntimeError("busy")

        for _ in range(3):
            self.run_deliver(calls, [notice], failing, withheld, owner_room)
        self.assertEqual(len(attempts), 1)
        self.assertEqual(
            [c for c in calls if c[0] == "wake_failed"], [("wake_failed", {"id": 7})]
        )

        asked = []
        stranger = {"@hugo:x": {}, "@ciel:x": {}, "@evil:x": {}}
        self.run_deliver(asked, [notice], failing, {}, stranger)
        withheld = {}
        for _ in range(3):
            self.run_deliver(asked, [{**notice, "id": 8}], failing, withheld, stranger)
        self.assertNotIn(("ack", {"id": 8, "as": "wake"}), asked)

    def test_poll_interval_is_short_and_retries_stay_bounded(self):
        self.assertLessEqual(ciel_watch.POLL, 3)
        self.assertGreaterEqual(ciel_watch.WAKE_RETRY, ciel_watch.POLL)
        self.assertLessEqual(ciel_watch.MAX_BACKOFF, 300)


class AckTimingTests(Case):
    def test_notice_reports_its_age_and_ack_records_delivery_time(self):
        start(self.d, "a")
        self.t3.threads["thread-1"]["runs"] = [self.t3.run(1, "failed", "thread-1")]
        self.d.tick()
        self.clock.advance(3.5)
        (notice,) = self.d.handle("notices", {})
        self.assertEqual(notice["age"], 3.5)
        self.d.handle("ack", {"id": notice["id"], "as": "wake"})
        row = self.d.store.db.execute("SELECT delivered_at FROM notices").fetchone()
        self.assertEqual(row[0], self.clock())


if __name__ == "__main__":
    unittest.main()
