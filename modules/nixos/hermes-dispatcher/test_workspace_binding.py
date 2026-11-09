"""Launch order: a task is sent only after T3 holds the worktree and the model.

Live failure, 2026-11-09 22:31:45 UTC: t3_thread_launch returned an idle thread
while T3 was still preparing the worktree. Ciel sent the first message at once, a
session opened in the project root, and T3's own `<launch>:workspace` metadata
update then detached it ("Workspace changed.").
"""

import time
import unittest
from unittest.mock import patch

from test_support import Clock, FakeT3, Workspace, make_dispatcher, start

SELECTION = {
    "instanceId": "claudeAgent",
    "model": "claude-fable-5-2",
    "options": [{"id": "effort", "value": "medium"}],
}
WORKTREE = "/home/hugob/.t3/worktrees/yomi/t3-abc"
BRANCH = "ciel/0123456789ab"


def payload(strategy=None):
    return {
        "commandId": "stable",
        "projectId": "repo",
        "title": "Fix",
        "initialMessage": {"text": "Task", "attachments": []},
        "workspaceStrategy": strategy
        or {"type": "worktree", "baseRef": "HEAD", "branch": BRANCH},
        "modelSelection": SELECTION,
        "runtimeMode": "full-access",
        "interactionMode": "default",
    }


class Native:
    """Plays T3: the worktree appears only when a test says so."""

    def __init__(self, worktree=None, branch=None):
        self.calls = []
        self.worktree, self.branch = worktree, branch

    def call(self, name, args, key=None):
        self.calls.append((name, args, key))
        if name == "t3_thread_launch":
            return {"threadId": "idle", "link": "t3://idle"}
        if name == "t3_thread_read":
            return {
                "thread": {
                    "threadId": args["threadId"],
                    "worktreePath": self.worktree,
                    "branch": self.branch,
                },
                "items": [],
            }
        if name == "t3_thread_configure":
            return {"modelSelection": SELECTION}
        return {}

    def names(self):
        return [name for name, _, _ in self.calls]


class BackendTests(unittest.TestCase):
    def backend(self, native):
        from t3_backend import T3Backend

        return T3Backend(native, None)

    def test_no_message_is_sent_while_t3_has_not_attached_the_worktree(self):
        from workspace_binding import WorkspaceNotReady

        native = Native(worktree=None)
        with self.assertRaises(WorkspaceNotReady) as raised:
            self.backend(native)("orchestration.launchThread", payload())
        self.assertEqual(raised.exception.thread, "idle")
        self.assertNotIn("t3_thread_send", native.names())
        self.assertNotIn(
            "t3_thread_configure", native.names(), "workspace comes before the model"
        )

    def test_the_task_is_sent_once_the_stored_worktree_is_the_expected_one(self):
        native = Native(worktree=WORKTREE, branch=BRANCH)
        self.backend(native)("orchestration.launchThread", payload())
        self.assertEqual(
            native.names(),
            [
                "t3_thread_launch",
                "t3_thread_read",
                "t3_thread_configure",
                "t3_thread_send",
            ],
        )
        read = native.calls[1]
        self.assertIsNone(read[2], "a read needs no durable receipt")
        self.assertEqual(native.calls[3][2], "stable:start")

    def test_a_delayed_attachment_is_waited_for_across_retries_without_a_second_start(
        self,
    ):
        from workspace_binding import WorkspaceNotReady

        native = Native(worktree=None)
        backend = self.backend(native)
        for _ in range(3):
            with self.assertRaises(WorkspaceNotReady):
                backend("orchestration.launchThread", payload())
        native.worktree, native.branch = WORKTREE, BRANCH
        backend("orchestration.launchThread", payload())
        self.assertEqual(native.names().count("t3_thread_send"), 1)
        launches = [c for c in native.calls if c[0] == "t3_thread_launch"]
        self.assertEqual({c[1]["clientRequestId"] for c in launches}, {"stable"})

    def test_a_different_branch_never_starts_a_run(self):
        from workspace_binding import WorkspaceNotBound

        native = Native(worktree=WORKTREE, branch="t3/other")
        with self.assertRaises(WorkspaceNotBound):
            self.backend(native)("orchestration.launchThread", payload())
        self.assertNotIn("t3_thread_send", native.names())

    def test_an_existing_worktree_must_be_the_requested_path(self):
        from workspace_binding import WorkspaceNotBound

        strategy = {"type": "existing_worktree", "worktreePath": WORKTREE}
        wrong = Native(worktree="/repo")
        with self.assertRaises(WorkspaceNotBound):
            self.backend(wrong)("orchestration.launchThread", payload(strategy))
        self.assertNotIn("t3_thread_send", wrong.names())
        right = Native(worktree=WORKTREE)
        self.backend(right)("orchestration.launchThread", payload(strategy))
        self.assertIn("t3_thread_send", right.names())

    def test_the_project_root_needs_no_attachment(self):
        native = Native(worktree=None)
        self.backend(native)("orchestration.launchThread", payload({"type": "root"}))
        self.assertNotIn("t3_thread_read", native.names())
        self.assertIn("t3_thread_send", native.names())


class DispatcherTests(unittest.TestCase):
    def setUp(self):
        self.work = Workspace().__enter__()
        self.addCleanup(self.work.__exit__)
        self.t3, self.clock = FakeT3(), Clock()
        patcher = patch.object(time, "time", self.clock)
        patcher.start()
        self.addCleanup(patcher.stop)

    def dispatcher(self):
        return make_dispatcher(self.work.db(), self.t3, limit=2)

    def block(self):
        from workspace_binding import WorkspaceNotReady

        self.t3.fail["orchestration.launchThread"] = WorkspaceNotReady(
            "thread-1", "t3://thread-1"
        )

    def test_a_pending_workspace_keeps_the_thread_and_starts_nothing(self):
        self.block()
        d = self.dispatcher()
        start(d, "a")
        task = d.store.task("a")
        self.assertEqual(task["last_status"], "launching")
        self.assertEqual(task["thread_id"], "thread-1", "retries reuse this thread")
        self.assertGreater(task["next_check"], self.clock())
        self.assertEqual(task["failures"], 0, "waiting is not a failure")
        self.assertEqual(
            d.store.db.execute("SELECT COUNT(*) FROM notices").fetchone()[0], 0
        )

    def test_the_launch_resumes_when_the_worktree_arrives_and_never_duplicates(self):
        self.block()
        d = self.dispatcher()
        start(d, "a")
        del self.t3.fail["orchestration.launchThread"]
        d.tick()
        self.assertEqual(
            d.store.task("a")["last_status"],
            "launching",
            "still inside the backoff window",
        )
        self.clock.advance(60)
        d.tick()
        self.assertIn(d.store.task("a")["last_status"], {"preparing", "running"})
        self.assertEqual(len(self.t3.threads), 1)

    def test_an_attachment_that_never_arrives_ends_without_a_run(self):
        self.block()
        d = self.dispatcher()
        start(d, "a")
        for _ in range(40):
            self.clock.advance(60)
            d.tick()
        task = d.store.task("a")
        self.assertEqual(task["last_status"], "needs_user")
        self.assertEqual(task["thread_id"], "thread-1")
        notice = d.store.db.execute("SELECT body FROM notices").fetchone()[0]
        self.assertIn("Worktree", notice)
        self.assertIn("Es lief kein Agent", notice)

    def test_a_reply_cannot_reach_a_thread_that_still_waits_for_its_worktree(self):
        self.block()
        d = self.dispatcher()
        start(d, "a")
        with self.assertRaisesRegex(ValueError, "startet gerade"):
            d.reply({"task_key": "a", "message": "More", "request_id": "r1"})
        self.assertEqual(self.t3.dispatched, [])

    def test_a_restart_resumes_the_same_pending_launch(self):
        self.block()
        start(self.dispatcher(), "a")
        del self.t3.fail["orchestration.launchThread"]
        self.clock.advance(60)
        restarted = self.dispatcher()
        restarted.tick()
        self.assertEqual(len(self.t3.threads), 1)
        self.assertNotEqual(restarted.store.task("a")["last_status"], "launching")


if __name__ == "__main__":
    unittest.main()
