"""Durable command identities and task ownership for Ciel's T3 boundary."""

import hashlib
import json
import sqlite3
import uuid

TASK_COLUMNS = {
    "stop_command": "TEXT",
    "verification": "TEXT",
    "recovery": "TEXT",
    "thread_link": "TEXT",
    # The user's request, kept apart from the rendered prompt so a queued task
    # can pick up project preferences recorded after it was queued.
    "description": "TEXT",
    "depends_on": "TEXT",
    "serial_group": "TEXT",
    # A follow-up message was accepted but T3 may still show the previous run.
    "pending_command": "TEXT",
    "baseline_ordinal": "INTEGER NOT NULL DEFAULT 0",
    "pending_since": "REAL",
    # Observation health: bounded exponential backoff survives restarts.
    "failures": "INTEGER NOT NULL DEFAULT 0",
    "next_check": "REAL",
    "last_error": "TEXT",
    "observed_at": "REAL",
}


def command_id(key):
    return "ciel:" + str(uuid.uuid5(uuid.NAMESPACE_URL, key))


class Store:
    def __init__(self, path):
        self.db = sqlite3.connect(path)
        self.db.row_factory = sqlite3.Row
        self.db.execute("PRAGMA journal_mode=WAL")
        self.db.execute(
            "CREATE TABLE IF NOT EXISTS tasks (task_key TEXT PRIMARY KEY, payload TEXT NOT NULL, thread_id TEXT, room_id TEXT, last_status TEXT NOT NULL, stop_command TEXT)"
        )
        have = {row[1] for row in self.db.execute("PRAGMA table_info(tasks)")}
        for name, kind in TASK_COLUMNS.items():
            if name not in have:
                self.db.execute(f"ALTER TABLE tasks ADD COLUMN {name} {kind}")
        self.db.execute(
            "CREATE TABLE IF NOT EXISTS commands (operation_key TEXT PRIMARY KEY, digest TEXT NOT NULL)"
        )
        self.db.execute(
            "CREATE TABLE IF NOT EXISTS notices (id INTEGER PRIMARY KEY, task_key TEXT NOT NULL, room_id TEXT NOT NULL, body TEXT NOT NULL, delivered INTEGER NOT NULL DEFAULT 0)"
        )
        if "dedup_key" not in {
            row[1] for row in self.db.execute("PRAGMA table_info(notices)")
        }:
            self.db.execute("ALTER TABLE notices ADD COLUMN dedup_key TEXT")
        # One notice per meaningful event, however often a poll re-derives it.
        self.db.execute(
            "CREATE UNIQUE INDEX IF NOT EXISTS notices_dedup ON notices(dedup_key) WHERE dedup_key IS NOT NULL"
        )
        self.db.commit()

    def seen(self, key):
        return (
            self.db.execute(
                "SELECT 1 FROM commands WHERE operation_key=?", (key,)
            ).fetchone()
            is not None
        )

    def reserve(self, key, data, apply=None):
        """Reserve an operation key; `apply(db)` runs once, atomically with the first reservation."""
        digest = hashlib.sha256(json.dumps(data, sort_keys=True).encode()).hexdigest()
        row = self.db.execute(
            "SELECT digest FROM commands WHERE operation_key=?", (key,)
        ).fetchone()
        if row and row["digest"] != digest:
            raise ValueError("Operation key already belongs to different arguments")
        if not row:
            self.db.execute("INSERT INTO commands VALUES (?, ?)", (key, digest))
            if apply:
                apply(self.db)
        self.db.commit()
        return command_id(key)

    def notify(self, task, dedup_key, body):
        """Queue one owner-DM notice; the same event never queues twice."""
        cursor = self.db.execute(
            "INSERT OR IGNORE INTO notices(task_key,room_id,body,dedup_key) VALUES(?,?,?,?)",
            (task["task_key"], task["room_id"], body, dedup_key),
        )
        self.db.commit()
        return cursor.rowcount == 1

    def task(self, key):
        row = self.db.execute("SELECT * FROM tasks WHERE task_key=?", (key,)).fetchone()
        if row is None:
            raise ValueError("Unknown task; Ciel may control only its own tasks")
        return dict(row)
