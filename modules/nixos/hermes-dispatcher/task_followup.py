"""Bounded, idempotent requests to finish PR creation or fix CI."""

import time
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
    # The previous run stays visible in T3 until the new one starts; remember
    # its ordinal so it is not read as the answer to this follow-up.
    dispatcher.store.db.execute(
        "UPDATE tasks SET last_status='preparing', pending_command=?, baseline_ordinal=?, pending_since=? WHERE task_key=? AND pending_command IS NOT ?",
        (
            command,
            state["latest_run"].get("ordinal", 0),
            time.time(),
            task["task_key"],
            command,
        ),
    )
    dispatcher.store.db.commit()
    return True
