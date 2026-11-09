"""Hugo's additions to a task that is still waiting for its T3 thread.

They are stored durably and folded into the first prompt, so the worker sees
them before it starts. An addition that arrives during the launch itself is
sent to the new thread once its id is known, still exactly once.
"""

import time
import uuid


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


def deliver_late(dispatcher, task):
    for row in pending(dispatcher, task["task_key"]):
        command = dispatcher.store.reserve(
            "supplement:" + row["operation_key"], {"message": row["message"]}
        )
        dispatcher.rpc(
            "orchestration.dispatchCommand",
            {
                "type": "message.dispatch",
                "commandId": command,
                "threadId": task["thread_id"],
                "messageId": str(uuid.uuid5(uuid.NAMESPACE_URL, command)),
                "text": "Ergänzung von Hugo zum laufenden Auftrag:\n" + row["message"],
                "attachments": [],
                "dispatchMode": {"type": "queue_after_active"},
            },
        )
        dispatcher.store.db.execute(
            "UPDATE supplements SET state='sent' WHERE operation_key=?",
            (row["operation_key"],),
        )
        dispatcher.store.db.commit()
