"""Ciel as orchestrator: worker questions, additions, pinned models and solved threads."""

import time
import unittest
from unittest.mock import patch

from model_selection import ModelNotEnforced
from test_support import Clock, FakeT3, Workspace, make_dispatcher, start

FABLE = {"provider": "claudeAgent", "model": "claude-fable-5-2", "effort": "medium"}
CLAUDE_READY = {
    "instanceId": "claudeAgent",
    "enabled": True,
    "installed": True,
    "status": "ready",
}


class Case(unittest.TestCase):
    def setUp(self):
        self.work = Workspace().__enter__()
        self.addCleanup(self.work.__exit__)
        self.t3, self.clock = FakeT3(), Clock()
        patcher = patch.object(time, "time", self.clock)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.d = self.dispatcher()

    def dispatcher(self, limit=2):
        d = make_dispatcher(self.work.db(), self.t3, limit=limit)
        d.config["selectableModels"] = {
            "claudeAgent": {"claude-fable-5-2": ["low", "medium"]},
            "codex": {"sol": ["medium"]},
        }
        return d

    def events(self):
        return [n["body"] for n in self.work.notices(self.d)]

    def answer(self, key="a", request=None, answers=None, rid="r1"):
        return self.d.handle(
            "answer",
            {
                "task_key": key,
                "request": request or self.d.handle("requests", {})[0]["request"],
                "request_id": rid,
                "answers": answers or {"Welche Farbe?": "Grün"},
            },
        )


class QuestionTests(Case):
    def test_question_in_a_running_run_is_seen_once_and_attributed(self):
        start(self.d, "a")
        self.t3.ask("thread-1")
        for _ in range(3):
            self.d.tick()
        (listed,) = self.d.handle("requests", {})
        self.assertEqual(listed["task_key"], "a")
        self.assertEqual(listed["thread_id"], "thread-1")
        self.assertEqual(listed["run_id"], "thread-1-run-1")
        self.assertTrue(listed["request"].startswith("q-"))
        self.assertEqual(listed["questions"][0]["options"], ["Blau", "Grün"])
        (event,) = [e for e in self.events() if "Rückfrage" in e]
        self.assertIn("<worker_question>", event)
        self.assertEqual(self.d.store.task("a")["last_status"], "running")

    def test_answer_continues_the_same_run_and_starts_no_new_one(self):
        start(self.d, "a")
        self.t3.ask("thread-1")
        self.d.tick()
        result = self.answer()
        self.assertTrue(result["accepted"])
        self.assertTrue(result["same_run"])
        self.assertTrue(result["continued"])
        self.assertEqual(len(self.t3.answered), 1)
        self.assertEqual(self.t3.answered[0]["answers"], {"Welche Farbe?": "Grün"})
        self.assertEqual(self.t3.dispatched, [], "no thread message, no new run")
        self.assertEqual(self.d.handle("requests", {}), [])

    def test_a_retried_answer_is_not_sent_twice(self):
        start(self.d, "a")
        self.t3.ask("thread-1")
        self.d.tick()
        handle = self.d.handle("requests", {})[0]["request"]
        self.answer(request=handle)
        again = self.answer(request=handle)
        self.assertTrue(again["already_answered"])
        self.assertEqual(len(self.t3.answered), 1)
        with self.assertRaisesRegex(ValueError, "nicht mehr offen"):
            self.answer(request=handle, rid="other")
        self.assertEqual(len(self.t3.answered), 1)

    def test_multi_part_question_needs_every_part(self):
        start(self.d, "a")
        self.t3.ask(
            "thread-1",
            questions=[
                {"id": "one", "question": "Eins?", "options": []},
                {"id": "two", "question": "Zwei?", "options": [], "multiSelect": True},
            ],
        )
        self.d.tick()
        with self.assertRaisesRegex(ValueError, "Mehrteilige"):
            self.answer(answers={"one": "ja"})
        with self.assertRaisesRegex(ValueError, "genau eine"):
            self.answer(answers={"one": ["a", "b"], "two": "x"}, rid="r2")
        self.assertEqual(self.t3.answered, [])
        self.answer(answers={"one": "ja", "two": ["a", "b"]}, rid="r3")
        self.assertEqual(len(self.t3.answered), 1)

    def test_question_answered_elsewhere_is_stale_and_nothing_is_sent(self):
        start(self.d, "a")
        self.t3.ask("thread-1")
        self.d.tick()
        handle = self.d.handle("requests", {})[0]["request"]
        self.t3.threads["thread-1"]["requests"] = []  # Hugo answered in T3
        with self.assertRaisesRegex(ValueError, "veraltet"):
            self.answer(request=handle)
        self.assertEqual(self.t3.answered, [])

    def test_a_handle_answers_only_its_own_task(self):
        start(self.d, "a"), start(self.d, "b")
        self.t3.ask("thread-2", request_id="req-b")
        self.d.tick()
        (listed,) = self.d.handle("requests", {})
        self.assertEqual(listed["task_key"], "b")
        with self.assertRaisesRegex(ValueError, "gehört nicht"):
            self.answer(key="a", request=listed["request"])
        self.assertEqual(self.t3.answered, [])

    def test_reply_while_a_question_is_open_is_refused(self):
        start(self.d, "a")
        self.t3.ask("thread-1")
        self.d.tick()
        with self.assertRaisesRegex(ValueError, "ciel_task_answer"):
            self.d.handle(
                "reply", {"task_key": "a", "request_id": "x", "message": "Grün"}
            )
        self.assertEqual(self.t3.dispatched, [])

    def test_stopping_closes_open_questions(self):
        start(self.d, "a")
        self.t3.ask("thread-1")
        self.d.tick()
        self.d.handle("stop", {"task_key": "a", "request_id": "s"})
        self.assertEqual(self.d.handle("requests", {}), [])
        with self.assertRaises(ValueError):
            self.answer(request="q-anything")

    def test_restart_does_not_duplicate_question_events(self):
        start(self.d, "a")
        self.t3.ask("thread-1")
        self.d.tick()
        self.d = self.dispatcher()  # broker restart on the same database
        self.d.tick(), self.d.tick()
        self.assertEqual(len([e for e in self.events() if "Rückfrage" in e]), 1)


class SupplementTests(Case):
    def test_addition_to_a_queued_task_reaches_its_first_prompt_once(self):
        self.d = self.dispatcher(limit=1)
        start(self.d, "a"), start(self.d, "b")
        stored = self.d.handle(
            "reply",
            {"task_key": "b", "request_id": "add-1", "message": "Bitte auch Tests"},
        )
        self.assertTrue(stored["stored"])
        # The same request_id again stores nothing new.
        self.d.handle(
            "reply",
            {"task_key": "b", "request_id": "add-1", "message": "Bitte auch Tests"},
        )
        self.d = self.dispatcher(limit=1)  # survives a restart
        self.t3.green_pr("thread-1")
        self.t3.finish("thread-1")
        self.d.tick()
        prompt = self.t3.launches[1]["initialMessage"]["text"]
        self.assertEqual(prompt.count("Bitte auch Tests"), 1)
        self.d.tick()
        self.assertEqual(self.t3.dispatched, [], "not resent as a message")

    def test_stopped_task_drops_its_waiting_additions(self):
        self.d = self.dispatcher(limit=1)
        start(self.d, "a"), start(self.d, "b")
        self.d.handle("reply", {"task_key": "b", "request_id": "x", "message": "m"})
        self.d.handle("stop", {"task_key": "b", "request_id": "s"})
        self.assertEqual(
            self.d.summary(self.d.store.task("b"))["pending_supplements"], 0
        )
        with self.assertRaisesRegex(ValueError, "gestoppt"):
            self.d.handle("reply", {"task_key": "b", "request_id": "y", "message": "m"})


class PinnedModelTests(Case):
    def setUp(self):
        super().setUp()
        self.t3.providers = [
            {**self.t3.providers[0], "status": "ready"},
            CLAUDE_READY,
        ]

    def test_explicit_fable_medium_is_launched_exactly(self):
        start(self.d, "a", **FABLE)
        (launch,) = self.t3.launches
        self.assertEqual(
            launch["modelSelection"],
            {
                "instanceId": "claudeAgent",
                "model": "claude-fable-5-2",
                "options": [{"id": "effort", "value": "medium"}],
            },
        )
        summary = self.d.summary(self.d.store.task("a"))
        self.assertEqual(
            summary["model"],
            {
                "provider": "claudeAgent",
                "model": "claude-fable-5-2",
                "effort": "medium",
                "pinned": True,
            },
        )

    def test_effort_above_the_allowlist_is_refused_before_anything_queues(self):
        with self.assertRaisesRegex(ValueError, "nicht freigegeben"):
            start(self.d, "a", **{**FABLE, "effort": "high"})
        with self.assertRaisesRegex(ValueError, "gemeinsam"):
            start(self.d, "b", model="claude-fable-5-2")
        self.assertEqual(self.d.tasks(), [])

    def test_model_missing_from_the_live_catalog_is_refused(self):
        self.t3.catalog[0]["models"] = []
        self.t3.catalog[0]["models"].append({"id": "claude-fable-5-1", "options": []})
        with self.assertRaisesRegex(ValueError, "nicht an"):
            start(self.d, "a", **FABLE)
        self.assertEqual(self.t3.launches, [])

    def test_unavailable_pinned_provider_waits_and_never_substitutes(self):
        self.t3.providers = [self.t3.providers[0], {**CLAUDE_READY, "status": "error"}]
        start(self.d, "a", **FABLE)
        start(self.d, "b")  # an unpinned task may still use Codex
        self.assertEqual(self.d.store.task("a")["last_status"], "waiting_quota")
        self.assertEqual(
            [x["modelSelection"]["instanceId"] for x in self.t3.launches], ["codex"]
        )
        self.assertTrue(any("weiche auf kein anderes" in e for e in self.events()))

    def test_stored_configuration_mismatch_starts_nothing(self):
        self.t3.fail["orchestration.launchThread"] = ModelNotEnforced(
            "idle-1", "t3://idle-1", {"modelSelection": {"model": "other"}}
        )
        start(self.d, "a", **FABLE)
        task = self.d.store.task("a")
        self.assertEqual(task["last_status"], "needs_user")
        self.assertEqual(task["thread_id"], "idle-1")
        self.d.tick(), self.d.tick()
        self.assertEqual(self.t3.calls.count("orchestration.launchThread"), 1)
        # A later reply cannot start the idle thread under the wrong model.
        self.t3.configured["idle-1"] = {"instanceId": "codex", "model": "sol"}
        with self.assertRaisesRegex(ValueError, "weicht"):
            self.d.handle(
                "reply", {"task_key": "a", "request_id": "r", "message": "go"}
            )

    def test_run_under_another_model_is_stopped(self):
        start(self.d, "a", **FABLE)
        self.t3.threads["thread-1"]["runs"] = [
            {
                **self.t3.run(1, "running", "thread-1"),
                "providerInstanceId": "claudeAgent",
                "model": "claude-opus-5-5",
            }
        ]
        self.d.tick()
        self.assertEqual(self.d.store.task("a")["last_status"], "needs_user")
        self.assertEqual(self.t3.dispatched[-1]["type"], "thread.stop")


class SolveTests(Case):
    def solve(self, key="a", rid="s1"):
        return self.d.handle("solve", {"task_key": key, "request_id": rid})

    def test_a_finished_agent_alone_is_not_solved(self):
        start(self.d, "a")
        result = self.solve()
        self.assertFalse(result["solved"])
        self.assertTrue(any("nicht abgeschlossen" in b for b in result["blockers"]))
        self.t3.finish("thread-1")  # completed, but no PR
        self.assertFalse(self.solve()["solved"])
        self.assertEqual(self.t3.settled, [])

    def test_green_pr_without_an_approving_review_stays_open(self):
        start(self.d, "a")
        self.t3.green_pr("thread-1")
        self.t3.finish("thread-1")
        result = self.solve()
        self.assertFalse(result["solved"])
        self.assertIn("keine freigebende Review nachgewiesen", result["blockers"][0])

    def test_open_question_keeps_it_open(self):
        start(self.d, "a")
        self.t3.green_pr("thread-1")
        self.t3.pull_requests["summary"]["reviewDecision"] = "approved"
        self.t3.finish("thread-1")
        self.t3.ask("thread-1")
        self.d.tick()
        self.assertFalse(self.solve()["solved"])

    def test_approved_green_pr_is_settled_and_confirmed(self):
        start(self.d, "a")
        self.t3.green_pr("thread-1")
        self.t3.pull_requests["summary"]["reviewDecision"] = "approved"
        self.t3.finish("thread-1")
        result = self.solve()
        self.assertTrue(result["solved"])
        self.assertEqual(result["evidence"][0]["head"], "abc123")
        self.assertEqual(len(self.t3.settled), 1)
        self.assertTrue(self.solve(rid="s2")["already"])
        self.assertEqual(len(self.t3.settled), 1)

    def test_merged_pr_is_solved(self):
        start(self.d, "a")
        self.t3.green_pr("thread-1")
        self.t3.pull_requests["detail"]["state"] = "merged"
        self.t3.finish("thread-1")
        self.assertTrue(self.solve()["solved"])

    def test_stopped_task_stays_stopped(self):
        start(self.d, "a")
        self.d.handle("stop", {"task_key": "a", "request_id": "s"})
        with self.assertRaisesRegex(ValueError, "bleibt gestoppt"):
            self.solve()
        self.assertEqual(self.t3.settled, [])


class DiagnosticsTests(Case):
    def test_overview_names_missing_t3_tools_and_stuck_delivery(self):
        start(self.d, "a")
        self.t3.tools = {"t3_thread_read"}
        view = self.d.handle("tasks", {})
        self.assertIn("t3_pending_request", view["t3_capabilities"]["missing"])
        self.assertIn("t3_thread_organize", view["t3_capabilities"]["missing"])
        self.d.store.notify(self.d.store.task("a"), "e", "x")
        self.d.handle("wake_failed", {"id": 1})
        self.assertEqual(
            self.d.handle("tasks", {})["delivery"],
            {"undelivered": 1, "wake_failing": 1},
        )

    def test_history_is_bounded_and_owned(self):
        start(self.d, "a")
        self.t3.finish("thread-1", reply="Ergebnis")
        page = self.d.handle("history", {"task_key": "a"})
        self.assertEqual(page["items"][0]["text"], "Ergebnis")
        with self.assertRaisesRegex(ValueError, "own"):
            self.d.handle("history", {"task_key": "foreign"})


if __name__ == "__main__":
    unittest.main()
