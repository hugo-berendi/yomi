"""Matrix threads inside Hugo's own encrypted DM, one per concrete topic.

The broker cannot talk to an encrypted room, so it only records a request. The
Hermes adapter (ciel_watch) posts the thread root with its own E2EE session and
reports the event ID back. Only roots created this way are ever addressed:
Ciel passes a short key, never a room or event ID, so a thread can neither
point at another room nor at a message Hugo or a worker wrote.
"""

import re
import time

KEY = re.compile(r"[a-zA-Z0-9_.:-]{1,100}")
EVENT = re.compile(r"\$[A-Za-z0-9_+/=.:-]{1,255}")
WAIT = 20


def ensure_schema(db):
    db.execute(
        "CREATE TABLE IF NOT EXISTS matrix_threads (thread_key TEXT PRIMARY KEY, room_id TEXT NOT NULL, title TEXT NOT NULL, root_event TEXT, created_at REAL NOT NULL)"
    )


def view(row):
    return {
        "thread_key": row["thread_key"],
        "state": "open" if row["root_event"] else "pending",
    }


def open_thread(db, room, args):
    key = str(args.get("thread_key", ""))
    if not KEY.fullmatch(key):
        raise ValueError("Invalid thread_key")
    title = " ".join(str(args.get("title", "")).split())[:100]
    if not title:
        raise ValueError("Ein Thread braucht einen kurzen Titel")
    row = db.execute(
        "SELECT * FROM matrix_threads WHERE thread_key=?", (key,)
    ).fetchone()
    if row is None:
        db.execute(
            "INSERT INTO matrix_threads VALUES (?,?,?,NULL,?)",
            (key, room, title, time.time()),
        )
        db.commit()
    elif row["room_id"] != room:
        raise ValueError("thread_key gehört zu einem anderen Raum")
    return view(
        db.execute("SELECT * FROM matrix_threads WHERE thread_key=?", (key,)).fetchone()
    )


def status(db, key):
    row = db.execute(
        "SELECT * FROM matrix_threads WHERE thread_key=?", (str(key),)
    ).fetchone()
    if row is None:
        raise ValueError("Unbekannter Thread; Ciel kann nur eigene Threads nutzen")
    return view(row)


def pending(db):
    return [
        {"thread_key": r["thread_key"], "room_id": r["room_id"], "title": r["title"]}
        for r in db.execute(
            "SELECT * FROM matrix_threads WHERE root_event IS NULL ORDER BY created_at LIMIT 5"
        )
    ]


def created(db, key, event):
    if not EVENT.fullmatch(str(event)):
        raise ValueError("Invalid Matrix event ID")
    db.execute(
        "UPDATE matrix_threads SET root_event=? WHERE thread_key=? AND root_event IS NULL",
        (event, str(key)),
    )
    db.commit()
    return {"recorded": True}


def root_for(db, key, room):
    """The root of an open thread in exactly this room, else a refusal."""
    row = db.execute(
        "SELECT * FROM matrix_threads WHERE thread_key=?", (str(key),)
    ).fetchone()
    if row is None or row["room_id"] != room:
        raise ValueError("thread_key ist unbekannt oder gehört zu einem anderen Raum")
    if not row["root_event"]:
        raise ValueError(
            "Der Thread ist noch nicht angelegt; ciel_thread_open erneut prüfen"
        )
    return row["root_event"]


def root_of_task(db, task):
    if not task.get("thread_key"):
        return None
    row = db.execute(
        "SELECT root_event FROM matrix_threads WHERE thread_key=? AND room_id=?",
        (task["thread_key"], task["room_id"]),
    ).fetchone()
    return row["root_event"] if row else None


def open_and_wait(call, args, sleep=time.sleep, tries=WAIT):
    """Open a thread and give the gateway a moment to post its root."""
    result = call("thread_open", args)
    for _ in range(tries):
        if result["state"] == "open":
            break
        sleep(1)
        result = call("thread_status", {"thread_key": result["thread_key"]})
    return result
