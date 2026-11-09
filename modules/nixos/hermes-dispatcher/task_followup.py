"""Bounded, idempotent requests to finish PR creation or fix CI."""

import uuid


def request_followup(dispatcher, task, state, reason):
    prefix = "finish:" + task["task_key"] + ":"
    previous = dispatcher.store.db.execute(
        "SELECT COUNT(*) FROM commands WHERE substr(operation_key,1,?)=?",
        (len(prefix), prefix),
    ).fetchone()[0]
    key = prefix + state["latest_run"]["id"]
    existing = dispatcher.store.db.execute(
        "SELECT 1 FROM commands WHERE operation_key=?", (key,)
    ).fetchone()
    if previous >= 2 and not existing:
        return False
    data = {
        "task_key": task["task_key"],
        "run_id": state["latest_run"]["id"],
        "reason": reason,
    }
    command = dispatcher.store.reserve(key, data)
    dispatcher.rpc(
        "orchestration.dispatchCommand",
        {
            "type": "message.dispatch",
            "commandId": command,
            "threadId": task["thread_id"],
            "messageId": str(uuid.uuid5(uuid.NAMESPACE_URL, command)),
            "text": "Continue the existing authorized task in its existing worktree. Independent PR verification found: "
            + reason
            + " Inspect actual state, address the blocker and finish the PR with exact-head checks. Do not duplicate issues or PRs, merge, deploy or weaken checks.",
            "attachments": [],
            "dispatchMode": {"type": "queue_after_active"},
        },
    )
    dispatcher.store.db.execute(
        "UPDATE tasks SET last_status='preparing' WHERE task_key=?", (task["task_key"],)
    )
    dispatcher.store.db.commit()
    return True
