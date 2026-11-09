"""Hugo's additions to a task that is still waiting for its T3 thread.

They are stored durably and folded into the first prompt in the same commit
that freezes it for launch, so the worker sees them before it starts. Once a
launch is under way, additions are refused with a retry hint instead.
"""

import time


def add(dispatcher, task, key, message):
    dispatcher.store.reserve(key, {"task_key": task["task_key"], "message": message})
    dispatcher.store.db.execute(
        "INSERT OR IGNORE INTO supplements(operation_key,task_key,message,created_at) VALUES(?,?,?,?)",
        (key, task["task_key"], message, time.time()),
    )
    dispatcher.store.db.commit()
    return {
        "task_key": task["task_key"],
        "stored": True,
        "delivery": "Wird beim Start in den ersten Auftrag aufgenommen.",
        "pending_supplements": len(pending(dispatcher, task["task_key"])),
    }


def pending(dispatcher, key):
    return dispatcher.store.db.execute(
        "SELECT * FROM supplements WHERE task_key=? AND state='pending' ORDER BY created_at",
        (key,),
    ).fetchall()


def include(dispatcher, task, payload):
    """Append pending additions to the first prompt; the caller commits with the payload."""
    rows = pending(dispatcher, task["task_key"])
    if not rows:
        return
    payload["initialMessage"]["text"] += (
        "\n<user_additions>\nHugo added these while the task waited. They refine user_task:\n"
        + "\n".join("- " + r["message"] for r in rows)
        + "\n</user_additions>\n"
    )
    dispatcher.store.db.executemany(
        "UPDATE supplements SET state='included' WHERE operation_key=?",
        [(r["operation_key"],) for r in rows],
    )
