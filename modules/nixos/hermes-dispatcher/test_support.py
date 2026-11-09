"""Shared fixture, named test_* so the Nix test build copies it: an in-memory T3 with command receipts, runs, projects and quota."""

import json
from pathlib import Path
import tempfile

from dispatch_core import Dispatcher
from dispatch_store import Store

ROUTES = {
    k: {"model": "sol", "effort": "medium"} for k in ("routine", "standard", "complex")
}
READY = {"instanceId": "codex", "enabled": True, "installed": True, "status": "ready"}


class FakeT3:
    """Answers the broker's backend operations. Tests mutate `threads` to play T3."""

    def __init__(self):
        self.threads, self.receipts, self.dispatched, self.launches = {}, {}, [], []
        self.providers = [READY]
        self.fail = {}  # operation -> exception raised on the next call(s)
        self.pull_requests, self.calls, self.broken = {}, [], set()

    def __call__(self, operation, payload=None, **kwargs):
        self.calls.append(operation)
        if self.fail.get(operation):
            raise self.fail[operation]
        if payload and payload.get("threadId") in self.broken:
            raise ValueError("T3 MCP tool refused the operation; no success assumed")
        if operation == "orchestration.subscribeShell":
            return {
                "kind": "snapshot",
                "snapshot": {
                    "projects": [
                        {"id": "allowed", "title": "Repo", "workspaceRoot": "/repo"}
                    ]
                },
            }
        if operation == "subscribeServerConfig":
            return {"config": {"providers": self.providers}}
        if operation == "orchestration.launchThread":
            self.launches.append(payload)
            thread = self.receipts.setdefault(
                payload["commandId"], "thread-%d" % (len(self.threads) + 1)
            )
            self.threads.setdefault(thread, {"runs": [], "messages": [], "prs": []})
            self.threads[thread]["runs"] = self.threads[thread]["runs"] or [
                self.run(1, "running", thread)
            ]
            return {"threadId": thread, "link": "t3://" + thread}
        if operation == "orchestration.getThreadProjection":
            thread = self.threads[payload["threadId"]]
            return {
                "runs": thread["runs"],
                "messages": [
                    {"role": "assistant", "text": t} for t in thread["messages"]
                ],
                "thread": {"pullRequests": thread["prs"]},
            }
        if operation == "orchestration.dispatchCommand":
            if payload["commandId"] not in self.receipts:
                self.receipts[payload["commandId"]] = True
                self.dispatched.append(payload)
            return {}
        if operation.startswith("pullRequests."):
            return self.pull_requests[operation.split(".")[1]]
        return {}

    @staticmethod
    def run(ordinal, status, thread="t"):
        return {"id": f"{thread}-run-{ordinal}", "ordinal": ordinal, "status": status}

    def green_pr(self, thread):
        link = {
            "url": "https://github.com/o/r/pull/1",
            "host": "github.com",
            "repository": "o/r",
            "number": 1,
        }
        self.threads[thread]["prs"] = [link]
        detail = {
            "headSha": "abc123",
            "state": "open",
            "url": link["url"],
            "isDraft": False,
            "mergeability": "mergeable",
            "checks": [{"status": "success", "required": True}],
        }
        self.pull_requests = {
            "detail": detail,
            "activity": {"reviewThreads": []},
            "summary": {"reviewDecision": None},
        }

    def finish(self, thread, ordinal=1, status="completed", reply="Done"):
        runs = self.threads[thread]["runs"]
        runs[:] = [r for r in runs if r["ordinal"] != ordinal] + [
            self.run(ordinal, status, thread)
        ]
        self.threads[thread]["messages"] = [reply]


class Clock:
    def __init__(self):
        self.now = 1_000_000.0

    def __call__(self):
        return self.now

    def advance(self, seconds):
        self.now += seconds


def make_dispatcher(path, t3, limit=2, memory=None, rooms=lambda config, room: room):
    config = {
        "projectIds": ["allowed"],
        "taste": "taste",
        "routes": ROUTES,
        "maxConcurrentTasks": limit,
    }
    if memory:
        config["memoryDirectory"] = memory
    return Dispatcher(config, Store(path), t3, verify_room=rooms)


def start(dispatcher, key, **extra):
    return dispatcher.start(
        {
            "task_key": key,
            "project_id": "allowed",
            "description": f"Do {key}",
            "room_id": "!room",
            **extra,
        }
    )


class Workspace:
    def __enter__(self):
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)
        return self

    def __exit__(self, *exc):
        self.directory.cleanup()

    def db(self):
        return self.root / "tasks.sqlite"

    def row(self, dispatcher, key):
        return dispatcher.store.task(key)

    def notices(self, dispatcher):
        return [
            dict(r)
            for r in dispatcher.store.db.execute("SELECT * FROM notices ORDER BY id")
        ]


def projects_file(root, entries):
    path = Path(root) / "projects.json"
    path.write_text(json.dumps(entries))
    return str(root)
