"""Scheduling and observation lifecycle: slots, queue, follow-ups, restarts."""

import time
import unittest
from unittest.mock import patch

from test_support import Clock, FakeT3, Workspace, make_dispatcher, projects_file, start


class LifecycleCase(unittest.TestCase):
    def setUp(self):
        self.work = Workspace().__enter__()
        self.addCleanup(self.work.__exit__)
        self.t3, self.clock = FakeT3(), Clock()
        patcher = patch.object(time, "time", self.clock)
        patcher.start()
        self.addCleanup(patcher.stop)

    def dispatcher(self, limit=2, **kwargs):
        return make_dispatcher(self.work.db(), self.t3, limit=limit, **kwargs)

    def status(self, d, key):
        return d.store.task(key)["last_status"]

    def complete(self, thread, ordinal=1):
        self.t3.green_pr(thread)
        self.t3.finish(thread, ordinal)


class SlotTests(LifecycleCase):
    def test_one_unreadable_task_cannot_starve_the_others(self):
        # Live symptom: "Ciel task poll deferred: ValueError" every 30 s while a
        # finished task kept its slot and a queued task never started.
        d = self.dispatcher()
        start(d, "a"), start(d, "b"), start(d, "c")
        d.tick()
        self.assertEqual(
            [self.status(d, k) for k in "abc"], ["running", "running", "queued"]
        )
        self.t3.broken.add("thread-1")
        self.complete("thread-2")
        d.tick()
        self.assertEqual(self.status(d, "b"), "ready")
        self.assertIsNotNone(
            d.store.task("c")["thread_id"], "freed slot must start the queue"
        )
        a = d.store.task("a")
        self.assertEqual(a["failures"], 1)
        self.assertIn("refused", a["last_error"])
        self.assertGreater(a["next_check"], self.clock())

    def test_concurrency_is_bounded_and_the_queue_advances_without_a_message(self):
        d = self.dispatcher(limit=2)
        for key in "abc":
            start(d, key)
        self.assertEqual(len(self.t3.launches), 2)
        waiting = d.summary(d.store.task("c"))["waiting_on"]
        self.assertEqual(waiting, {"kind": "slot", "used": 2, "limit": 2})
        self.assertEqual(d.overview()["slots"], {"used": 2, "limit": 2})
        for _ in range(3):
            d.tick()
            self.assertLessEqual(d.used(), 2)
        self.assertEqual(len(self.t3.launches), 2)
        self.complete("thread-1")
        d.tick()
        self.assertEqual(self.status(d, "a"), "ready")
        self.assertEqual(len(self.t3.launches), 3)
        self.assertLessEqual(d.used(), 2)
        branches = {p["workspaceStrategy"]["branch"] for p in self.t3.launches}
        self.assertEqual(len(branches), 3, "every task needs its own worktree branch")

    def test_idle_waiting_tasks_do_not_hold_a_slot(self):
        d = self.dispatcher(limit=1)
        start(d, "a"), start(d, "b")
        self.t3.threads["thread-1"]["runs"] = [self.t3.run(1, "waiting", "thread-1")]
        d.tick()
        self.assertEqual(self.status(d, "a"), "waiting")
        self.assertEqual(self.status(d, "b"), "preparing")

    def test_agent_status_queued_is_not_the_brokers_queue(self):
        d = self.dispatcher()
        start(d, "a")
        self.t3.threads["thread-1"]["runs"] = [self.t3.run(1, "queued", "thread-1")]
        d.tick(), d.tick()
        self.assertEqual(self.status(d, "a"), "preparing")
        self.assertEqual(len(self.t3.launches), 1)

    def test_dependencies_and_serial_groups_keep_conflicting_work_queued(self):
        d = self.dispatcher(limit=3)
        start(d, "a", serial_group="files")
        start(d, "b", depends_on=["a"])
        start(d, "c", serial_group="files")
        start(d, "free")
        self.assertEqual(
            [self.status(d, k) for k in ("a", "b", "c", "free")],
            ["preparing", "queued", "queued", "preparing"],
        )
        self.assertEqual(
            d.summary(d.store.task("b"))["waiting_on"],
            {"kind": "dependency", "task": "a"},
        )
        self.assertEqual(
            d.summary(d.store.task("c"))["waiting_on"],
            {"kind": "serial_group", "task": "a"},
        )
        with self.assertRaisesRegex(ValueError, "does not own"):
            start(d, "d", depends_on=["ghost"])
        with self.assertRaisesRegex(ValueError, "itself"):
            start(d, "e", depends_on=["e"])
        d.tick()
        self.complete("thread-1")
        d.tick()
        self.assertEqual(self.status(d, "a"), "ready")
        self.assertIsNotNone(d.store.task("b")["thread_id"])
        self.assertIsNotNone(d.store.task("c")["thread_id"])

    def test_failed_dependency_is_reported_once_and_never_starts_the_dependent(self):
        d = self.dispatcher()
        start(d, "a"), start(d, "b", depends_on=["a"])
        self.t3.threads["thread-1"]["runs"] = [self.t3.run(1, "failed", "thread-1")]
        for _ in range(4):
            d.tick()
        self.assertEqual(self.status(d, "b"), "queued")
        bodies = [n["body"] for n in self.work.notices(d) if n["task_key"] == "b"]
        self.assertEqual(len(bodies), 1)

    def test_launch_for_a_project_no_longer_authorized_asks_instead_of_crashing(self):
        d = self.dispatcher(limit=1)
        start(d, "a"), start(d, "b")
        d.config["projectIds"] = []
        self.complete("thread-1")
        d.tick(), d.tick()
        self.assertEqual(self.status(d, "b"), "needs_user")
        self.assertEqual(
            len([n for n in self.work.notices(d) if n["task_key"] == "b"]), 1
        )

    def test_queued_work_starts_with_preferences_recorded_while_it_waited(self):
        memory = projects_file(self.work.root, [])
        d = self.dispatcher(limit=1, memory=memory)
        start(d, "a"), start(d, "b")
        projects_file(
            self.work.root,
            [
                {
                    "fact": "Yomi changes need neither PR nor issue",
                    "topics": ["*"],
                    "source": "Hugo",
                    "date": "2026-11-09",
                }
            ],
        )
        self.complete("thread-1")
        d.tick()
        self.assertNotIn(
            "neither PR nor issue", self.t3.launches[0]["initialMessage"]["text"]
        )
        self.assertIn(
            "neither PR nor issue", self.t3.launches[1]["initialMessage"]["text"]
        )
        self.assertIn("Do b", self.t3.launches[1]["initialMessage"]["text"])


class RecoveryTests(LifecycleCase):
    def test_lost_launch_is_retried_with_backoff_then_handed_to_a_human(self):
        d = self.dispatcher(limit=1)
        self.t3.fail["orchestration.launchThread"] = TimeoutError("lost")
        with self.assertRaises(TimeoutError):
            start(d, "a")
        row = d.store.task("a")
        self.assertEqual((row["last_status"], row["failures"]), ("launching", 1))
        calls = len(self.t3.calls)
        d.tick()
        self.assertEqual(
            len(self.t3.calls), calls, "backoff must prevent a retry storm"
        )
        for _ in range(5):
            self.clock.advance(601)
            d.tick()
        row = d.store.task("a")
        self.assertEqual(row["last_status"], "uncertain_launch")
        self.assertEqual(len([n for n in self.work.notices(d)]), 1)
        self.assertEqual(d.used(), 1, "an unconfirmed launch still owns its slot")
        self.clock.advance(601)
        d.tick()
        self.assertEqual(len([n for n in self.work.notices(d)]), 1)

    def test_launch_that_the_server_accepted_converges_after_backoff(self):
        d = self.dispatcher()
        self.t3.fail["orchestration.launchThread"] = TimeoutError("reply lost")
        with self.assertRaises(TimeoutError):
            start(d, "a")
        del self.t3.fail["orchestration.launchThread"]
        d.tick()
        self.assertEqual(self.status(d, "a"), "launching")
        self.clock.advance(61)
        d.tick()
        self.assertEqual(self.status(d, "a"), "running")
        self.assertEqual(d.store.task("a")["failures"], 0)
        self.assertEqual(
            len(self.t3.threads), 1, "one worktree, however often the launch is retried"
        )

    def test_restart_keeps_backoff_queue_and_notices_without_duplicates(self):
        first = self.dispatcher(limit=1)
        start(first, "a"), start(first, "b")
        first.tick()
        self.complete("thread-1")
        second = self.dispatcher(limit=1)  # process restart: only SQLite survives
        second.tick()
        self.assertEqual(self.status(second, "a"), "ready")
        self.assertEqual(len(self.t3.launches), 2)
        count = len(self.work.notices(second))
        third = self.dispatcher(limit=1)
        calls = len(self.t3.launches)
        third.tick(), third.tick()
        self.assertEqual(len(self.work.notices(third)), count)
        self.assertEqual(len(self.t3.launches), calls)
        self.t3.broken.add("thread-2")
        third.tick()
        reads = len(self.t3.calls)
        self.dispatcher(limit=1).tick()
        self.assertEqual(
            len(self.t3.calls), reads, "persisted backoff survives restart"
        )


class MigrationTests(LifecycleCase):
    def test_database_from_the_previous_release_keeps_its_tasks_and_queue(self):
        import json
        import sqlite3

        old = sqlite3.connect(self.work.db())
        old.execute(
            "CREATE TABLE tasks (task_key TEXT PRIMARY KEY, payload TEXT NOT NULL, thread_id TEXT, room_id TEXT, last_status TEXT NOT NULL, stop_command TEXT, verification TEXT, recovery TEXT, thread_link TEXT)"
        )
        old.execute(
            "CREATE TABLE notices (id INTEGER PRIMARY KEY, task_key TEXT NOT NULL, room_id TEXT NOT NULL, body TEXT NOT NULL, delivered INTEGER NOT NULL DEFAULT 0)"
        )
        prompt = "preamble\n<user_task>\nLegacy request\n</user_task>\n"
        for key, thread, status in [
            ("old-running", "t-old", "running"),
            ("old-queued", None, "queued"),
        ]:
            payload = {
                "commandId": "ciel:" + key,
                "projectId": "allowed",
                "modelSelection": {
                    "model": "sol",
                    "options": [{"id": "reasoningEffort", "value": "medium"}],
                },
                "initialMessage": {"text": prompt, "attachments": []},
            }
            old.execute(
                "INSERT INTO tasks(task_key,payload,thread_id,room_id,last_status) VALUES(?,?,?,?,?)",
                (key, json.dumps(payload), thread, "!room", status),
            )
        old.commit()
        old.close()
        self.t3.threads["t-old"] = {
            "runs": [self.t3.run(1, "running", "t-old")],
            "messages": [],
            "prs": [],
        }
        d = self.dispatcher(
            memory=projects_file(
                self.work.root,
                [
                    {
                        "fact": "Fact",
                        "source": "Hugo",
                        "date": "2026-11-09",
                        "topics": ["*"],
                    }
                ],
            )
        )
        d.tick()
        self.assertEqual(self.status(d, "old-running"), "running")
        self.assertIsNotNone(d.store.task("old-queued")["thread_id"])
        text = self.t3.launches[0]["initialMessage"]["text"]
        self.assertIn("Legacy request", text)
        self.assertIn("- Fact (Hugo, 2026-11-09)", text)


class FollowUpTests(LifecycleCase):
    def finished_task(self):
        d = self.dispatcher()
        start(d, "a")
        d.tick()
        self.complete("thread-1")
        d.tick()
        self.assertEqual(self.status(d, "a"), "ready")
        return d

    def test_stale_completed_run_is_not_reported_for_a_followup(self):
        d = self.finished_task()
        before = len(self.work.notices(d))
        d.reply({"task_key": "a", "request_id": "r1", "message": "Please adjust"})
        row = d.store.task("a")
        self.assertEqual(
            (row["last_status"], row["baseline_ordinal"]), ("preparing", 1)
        )
        pr_calls = len([c for c in self.t3.calls if c.startswith("pullRequests")])
        d.tick()
        self.assertEqual(d.status("a")["status"], "preparing")
        self.assertEqual(self.status(d, "a"), "preparing")
        self.assertEqual(len(self.work.notices(d)), before)
        self.assertEqual(
            len([c for c in self.t3.calls if c.startswith("pullRequests")]), pr_calls
        )
        self.t3.threads["thread-1"]["runs"].append(
            self.t3.run(2, "running", "thread-1")
        )
        d.tick()
        row = d.store.task("a")
        self.assertEqual(
            (row["last_status"], row["pending_command"]), ("running", None)
        )
        self.t3.finish("thread-1", 2, reply="Adjusted")
        d.tick()
        self.assertEqual(self.status(d, "a"), "ready")
        # The second run's end is announced at once, then its verified result.
        self.assertEqual(len(self.work.notices(d)), before + 2)
        self.assertIn("Adjusted", self.work.notices(d)[-1]["body"])
        self.assertIn("PR grün", self.work.notices(d)[-1]["body"])

    def test_retried_reply_sends_once_and_keeps_its_baseline(self):
        d = self.finished_task()
        args = {"task_key": "a", "request_id": "r1", "message": "Please adjust"}
        d.reply(args)
        self.t3.threads["thread-1"]["runs"].append(
            self.t3.run(2, "running", "thread-1")
        )
        d.tick()
        d.reply(args)
        self.assertEqual(len(self.t3.dispatched), 1)
        row = d.store.task("a")
        self.assertEqual((row["baseline_ordinal"], row["pending_command"]), (1, None))
        with self.assertRaisesRegex(ValueError, "different arguments"):
            d.reply({**args, "message": "Something else"})

    def test_followup_that_never_starts_a_run_ends_in_a_notice_not_a_stuck_slot(self):
        d = self.finished_task()
        d.reply({"task_key": "a", "request_id": "r1", "message": "Please adjust"})
        self.clock.advance(901)
        d.tick()
        self.assertEqual(self.status(d, "a"), "needs_user")
        self.assertEqual(d.used(), 0)
        self.assertIn("Folgenachricht", self.work.notices(d)[-1]["body"])
        d.tick()
        self.assertEqual(
            len([n for n in self.work.notices(d) if "Folgenachricht" in n["body"]]), 1
        )

    def test_resuming_an_idle_task_needs_a_free_slot_but_a_running_one_queues(self):
        d = self.dispatcher(limit=1)
        start(d, "a"), start(d, "b")
        self.complete("thread-1")
        d.tick()
        self.assertEqual(
            (self.status(d, "a"), self.status(d, "b")), ("ready", "preparing")
        )
        with self.assertRaisesRegex(ValueError, "slots are busy"):
            d.reply({"task_key": "a", "request_id": "r1", "message": "More"})
        d.reply({"task_key": "b", "request_id": "r2", "message": "Also this"})
        self.assertEqual(
            self.t3.dispatched[-1]["dispatchMode"], {"type": "queue_after_active"}
        )

    def test_repair_followup_for_a_failed_ci_is_sent_once_per_run(self):
        d = self.dispatcher()
        start(d, "a")
        d.tick()
        self.complete("thread-1")
        self.t3.pull_requests["detail"]["checks"] = [{"status": "failure"}]
        d.tick(), d.tick()
        self.assertEqual(len(self.t3.dispatched), 1)
        self.assertEqual(self.status(d, "a"), "preparing")
        d.tick()
        self.assertEqual(
            len(self.t3.dispatched),
            1,
            "the old completed run must not trigger a second repair",
        )


if __name__ == "__main__":
    unittest.main()
