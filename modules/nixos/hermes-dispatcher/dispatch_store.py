"""Durable command identities and task ownership for Ciel's T3 boundary."""

import hashlib
import json
import sqlite3
import uuid


class Store:
    def __init__(self, path):
        self.db = sqlite3.connect(path)
        self.db.row_factory = sqlite3.Row
        self.db.execute("PRAGMA journal_mode=WAL")
        self.db.execute(
            "CREATE TABLE IF NOT EXISTS tasks (task_key TEXT PRIMARY KEY, payload TEXT NOT NULL, thread_id TEXT, room_id TEXT, last_status TEXT NOT NULL, stop_command TEXT)"
        )
        if "stop_command" not in {
            row[1] for row in self.db.execute("PRAGMA table_info(tasks)")
        }:
            self.db.execute("ALTER TABLE tasks ADD COLUMN stop_command TEXT")
        if "verification" not in {
            row[1] for row in self.db.execute("PRAGMA table_info(tasks)")
        }:
            self.db.execute("ALTER TABLE tasks ADD COLUMN verification TEXT")
        if "recovery" not in {
            row[1] for row in self.db.execute("PRAGMA table_info(tasks)")
        }:
            self.db.execute("ALTER TABLE tasks ADD COLUMN recovery TEXT")
        if "thread_link" not in {
            row[1] for row in self.db.execute("PRAGMA table_info(tasks)")
        }:
            self.db.execute("ALTER TABLE tasks ADD COLUMN thread_link TEXT")
        self.db.execute(
            "CREATE TABLE IF NOT EXISTS commands (operation_key TEXT PRIMARY KEY, digest TEXT NOT NULL)"
        )
        self.db.execute(
            "CREATE TABLE IF NOT EXISTS notices (id INTEGER PRIMARY KEY, task_key TEXT NOT NULL, room_id TEXT NOT NULL, body TEXT NOT NULL, delivered INTEGER NOT NULL DEFAULT 0)"
        )
        self.db.commit()

    def reserve(self, key, data):
        digest = hashlib.sha256(json.dumps(data, sort_keys=True).encode()).hexdigest()
        row = self.db.execute(
            "SELECT digest FROM commands WHERE operation_key=?", (key,)
        ).fetchone()
        if row and row["digest"] != digest:
            raise ValueError("Operation key already belongs to different arguments")
        self.db.execute("INSERT OR IGNORE INTO commands VALUES (?, ?)", (key, digest))
        self.db.commit()
        return "ciel:" + str(uuid.uuid5(uuid.NAMESPACE_URL, key))

    def task(self, key):
        row = self.db.execute("SELECT * FROM tasks WHERE task_key=?", (key,)).fetchone()
        if row is None:
            raise ValueError("Unknown task; Ciel may control only its own tasks")
        return dict(row)
