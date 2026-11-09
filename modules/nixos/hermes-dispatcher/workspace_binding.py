"""Confirm that T3 holds a thread's workspace before its first message.

t3_thread_launch returns once the thread exists. For a `worktree` strategy T3
then creates the checkout and records it in a `<launch>:workspace` metadata
update. A session opened before that update is detached by T3 ("Workspace
changed."), which surfaced as an unexpectedly closed provider event stream.
Ciel therefore reads the stored workspace back and sends only when it is the
one that was asked for. It never assigns a workspace itself.
"""


class WorkspaceNotReady(ValueError):
    """T3 has not attached the workspace yet; nothing was sent, retry later."""

    def __init__(self, thread, link):
        super().__init__("T3 hat den Worktree noch nicht zugewiesen")
        self.thread, self.link = thread, link


class WorkspaceNotBound(ValueError):
    """T3 attached a workspace other than the requested one; no run was started."""

    def __init__(self, thread, link, stored):
        super().__init__("T3 hat einen anderen als den angeforderten Worktree gesetzt")
        self.thread, self.link, self.stored = thread, link, stored


def confirm(native, thread, link, strategy):
    """Return once the thread's stored workspace matches `strategy`, else raise."""
    kind = (strategy or {"type": "root"}).get("type")
    if kind not in {"worktree", "existing_worktree"}:
        # The project checkout is the thread's workspace from creation.
        return
    detail = (
        native.call(
            "t3_thread_read",
            {
                "threadId": thread,
                "view": "messages",
                "limit": 1,
                "maxCharsPerItem": 1,
                "runLimit": 1,
            },
        ).get("thread")
        or {}
    )
    path, branch = detail.get("worktreePath"), detail.get("branch")
    if not path:
        raise WorkspaceNotReady(thread, link)
    stored = {"worktreePath": path, "branch": branch}
    if kind == "existing_worktree":
        wrong = path != strategy["worktreePath"]
    else:
        wrong = strategy.get("branch") is not None and branch != strategy["branch"]
    if wrong:
        raise WorkspaceNotBound(thread, link, stored)
