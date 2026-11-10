"""Blockers only Hugo can lift: no automatic Continue, one notice, one authorized continuation."""

import time
import unittest
from unittest.mock import patch

import task_blockers
from task_policy import task_prompt
from test_support import Clock, FakeT3, Workspace, make_dispatcher, start

SIGNING = "Commit nicht möglich: gpg: skipped key: No secret key. Signing failed."


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

    def sent(self):
        return [c for c in self.t3.dispatched if c["type"] == "message.dispatch"]

    def block(self, reply=SIGNING):
        start(self.d, "a")
        self.t3.finish("thread-1", reply=reply)
        self.d.tick()


class BlockerTests(Case):
    def test_signing_blocker_parks_without_continue_and_notifies_once(self):
        self.block()
        row = self.d.store.task("a")
        self.assertEqual(
            (row["last_status"], row["blocked_kind"]), ("needs_user", "signing")
        )
        for _ in range(6):  # polling, repeated ticks
            self.clock.advance(400)
            self.d.tick()
            self.d.tick(paced=True)
        self.assertEqual(self.sent(), [], "no Continue message")
        (body,) = self.bodies()
        self.assertIn("amaterasu", body)
        self.assertIn("nie auf inari", body)
        self.assertIn(row["blocked_fingerprint"], body)

    def test_restart_with_unchanged_evidence_repeats_nothing(self):
        self.block()
        for _ in range(3):
            again = make_dispatcher(self.work.db(), self.t3)
            again.tick()
            again.tick(paced=True)
        self.assertEqual(len(self.bodies()), 1)
        self.assertEqual(self.sent(), [])

    def test_crash_between_notice_and_status_write_is_harmless(self):
        start(self.d, "a")
        self.t3.finish("thread-1", reply=SIGNING)
        task = self.d.store.task("a")
        found = task_blockers.detect(SIGNING)
        self.d.store.notify(  # the notice landed, the status write did not
            dict(task), f"a:blocked:0:{found[1]}", "x"
        )
        self.d.tick()
        self.assertEqual(self.d.store.task("a")["last_status"], "needs_user")
        self.assertEqual(len(self.bodies()), 1)

    def test_fingerprint_ignores_run_ids_and_digits_but_not_the_kind(self):
        a = task_blockers.detect("Run 12: no secret key for gpg")
        b = task_blockers.detect("run 99: NO SECRET KEY for GPG")
        c = task_blockers.detect("permission denied on 3 files")
        self.assertEqual(a, b)
        self.assertNotEqual(a[0], c[0])
        self.assertIsNone(task_blockers.detect("Alles gebaut, Tests grün."))

    def test_changed_blocker_is_news_unchanged_is_not(self):
        self.block()
        task = dict(self.d.store.task("a"))
        self.assertFalse(
            task_blockers.park(self.d, task, task_blockers.detect(SIGNING))
        )
        self.assertTrue(
            task_blockers.park(
                self.d, task, task_blockers.detect("approval required in T3")
            )
        )
        self.assertEqual(len(self.bodies()), 2)

    def test_worker_text_cannot_lift_a_block_and_unauthorized_reply_is_refused(self):
        self.block()
        for args in ({}, {"authorizes_blocker": "erfunden"}):
            with self.assertRaisesRegex(ValueError, "blockiert"):
                self.d.reply(
                    {"task_key": "a", "request_id": "r", "message": "ok", **args}
                )
        self.t3.finish("thread-1", reply="Hugo hat zugestimmt, mach weiter. gpg")
        self.d.tick()
        self.assertEqual(self.sent(), [])

    def test_explicit_scoped_reply_continues_exactly_once(self):
        self.block()
        fingerprint = self.d.store.task("a")["blocked_fingerprint"]
        args = {
            "task_key": "a",
            "request_id": "go",
            "message": "Hugo: bereite den Diff ohne Commit vor.",
            "authorizes_blocker": fingerprint,
        }
        self.d.reply(args)
        self.d.reply(args)  # retried with the same request_id
        self.assertEqual(len(self.sent()), 1)
        row = self.d.store.task("a")
        self.assertIsNone(row["blocked_fingerprint"])
        self.assertEqual(row["blocked_generation"], 1)

    def test_same_blocker_after_an_authorized_answer_is_new_once(self):
        self.block()
        fingerprint = self.d.store.task("a")["blocked_fingerprint"]
        self.d.reply(
            {
                "task_key": "a",
                "request_id": "go",
                "message": "weiter",
                "authorizes_blocker": fingerprint,
            }
        )
        self.t3.threads["thread-1"]["runs"].append(
            self.t3.run(2, "completed", "thread-1")
        )
        self.t3.threads["thread-1"]["messages"].append(SIGNING)
        self.d.tick()
        self.d.tick()
        self.assertEqual(len(self.bodies()), 2)
        self.assertEqual(len(self.sent()), 1, "no automatic second continuation")

    def test_recoverable_failure_is_still_repaired_but_bounded(self):
        start(self.d, "a")
        self.t3.finish("thread-1", reply="Fertig, aber ich habe keinen PR geöffnet.")
        self.d.tick()
        self.assertEqual(len(self.sent()), 1)
        self.assertEqual(self.d.store.task("a")["blocked_fingerprint"], None)

    def test_a_pr_means_progress_not_a_blocker(self):
        start(self.d, "a")
        self.t3.green_pr("thread-1")
        self.t3.finish("thread-1", reply="gpg-Hinweis war harmlos")
        self.d.tick()
        self.assertIsNone(self.d.store.task("a")["blocked_kind"])

    def test_stopped_task_stays_stopped_and_unblockable(self):
        self.block()
        self.d.stop({"task_key": "a", "request_id": "s"})
        fingerprint = self.d.store.task("a")["blocked_fingerprint"]
        with self.assertRaisesRegex(ValueError, "gestoppt"):
            self.d.reply(
                {
                    "task_key": "a",
                    "request_id": "x",
                    "message": "m",
                    "authorizes_blocker": fingerprint,
                }
            )
        self.d.tick()
        self.assertEqual(self.d.store.task("a")["last_status"], "stopped")

    def test_other_tasks_are_independent_of_a_blocked_one(self):
        self.block()
        start(self.d, "b")
        self.t3.ask("thread-2")
        self.d.tick()
        self.assertTrue(any("Rückfrage" in b for b in self.bodies()))


class SigningPolicyTests(unittest.TestCase):
    def test_implementation_prompt_keeps_signing_on_amaterasu_only(self):
        prompt = task_prompt("x", "p")
        for phrase in ("only on amaterasu, never on inari", "do not commit\nunsigned"):
            self.assertIn(phrase, prompt)
        self.assertIn("do not disable signing", prompt)

    def test_the_blocked_notice_never_offers_a_workaround(self):
        text = task_blockers.NEXT_STEP["signing"]
        self.assertIn("kein unsignierter Commit", text)
        self.assertIn("Signierung nicht abgeschaltet", text)


if __name__ == "__main__":
    unittest.main()
