"""Narrow task API: registered projects, owned threads and stable server command IDs."""

import json
import re
import uuid
import time

from ciel_routing import choose
from task_policy import task_prompt
from provider_policy import codex_selection, select_provider
from matrix_rooms import private_room
from pr_verification import verify
from task_followup import request_followup


TERMINAL = {
    "completed",
    "failed",
    "cancelled",
    "interrupted",
    "rolled_back",
    "stopped",
    "ready",
    "merged",
    "needs_user",
}


def text(value, maximum=12000):
    if not isinstance(value, str) or not value.strip() or len(value) > maximum:
        raise ValueError("Expected nonempty bounded text")
    return value


class Dispatcher:
    def __init__(self, config, store, rpc, verify_room=private_room):
        self.config, self.store, self.rpc = config, store, rpc
        self.verify_room = verify_room
        self.ready_checked = {}

    def projects(self):
        item = self.rpc("orchestration.subscribeShell", {}, first=True)
        if item.get("kind") != "snapshot":
            raise RuntimeError("T3 did not return its project snapshot")
        return [
            {k: p[k] for k in ("id", "title", "workspaceRoot")}
            for p in item["snapshot"]["projects"]
            if p["id"] in self.config["projectIds"] and not p.get("archivedAt")
        ]

    def start(self, args):
        key = text(args.get("task_key"), 100)
        if not re.fullmatch(r"[a-zA-Z0-9_.:-]+", key):
            raise ValueError("Invalid task key")
        description = text(args.get("description"))
        room = self.verify_room(self.config, args.get("room_id"))
        if not room.startswith("!") or ":" not in room:
            raise ValueError(
                "A Matrix room ID is required for private completion delivery"
            )
        project_id = args.get("project_id")
        if not any(p["id"] == project_id for p in self.projects()):
            raise ValueError("Project is not registered and authorized for Ciel")
        command = self.store.reserve("start:" + key, args)
        existing = self.store.db.execute(
            "SELECT task_key FROM tasks WHERE task_key=?", (key,)
        ).fetchone()
        if not existing:
            tier = choose(description)
            selection = self.config["routes"][tier]
            thread_id = str(uuid.uuid5(uuid.NAMESPACE_URL, command))
            payload = {
                "commandId": command,
                "projectId": project_id,
                "title": "Ciel: " + description.splitlines()[0][:100],
                "modelSelection": codex_selection(selection),
                "runtimeMode": "full-access",
                "interactionMode": "default",
                "workspaceStrategy": {
                    "type": "worktree",
                    "baseRef": "HEAD",
                    "branch": "ciel/" + thread_id[:12],
                },
                "initialMessage": {
                    "text": task_prompt(
                        description,
                        self.config["taste"],
                        self.config.get("globalRules", ""),
                    ),
                    "attachments": [],
                },
            }
            self.store.db.execute(
                "INSERT INTO tasks(task_key,payload,thread_id,room_id,last_status) VALUES (?, ?, ?, ?, ?)",
                (key, json.dumps(payload), None, room, "queued"),
            )
            self.store.db.commit()
        self.tick()
        return self.summary(self.store.task(key))

    def summary(self, task):
        return {
            "task_key": task["task_key"],
            "status": task["last_status"],
            "broker_state": task["last_status"],
            "verification": json.loads(task["verification"])
            if task.get("verification")
            else None,
            "thread_id": task["thread_id"],
            "url": task.get("thread_link"),
        }

    def status(self, key):
        task = self.store.task(key)
        result = self.summary(task)
        if task["thread_id"] and task["last_status"] not in {
            "queued",
            "waiting_quota",
            "stopped",
            "stopping",
        }:
            projection = self.rpc(
                "orchestration.getThreadProjection", {"threadId": task["thread_id"]}
            )
            runs = projection["runs"]
            result["status"] = (
                max(runs, key=lambda r: r["ordinal"])["status"] if runs else "preparing"
            )
            result["agent_status"] = result["status"]
            if task["last_status"] in {
                "verifying",
                "ready",
                "needs_user",
                "quota_paused",
            }:
                result["status"] = task["last_status"]
            thread = projection.get("thread", {})
            links = thread.get("pullRequests") or [
                thread.get("linkedPullRequest") or thread.get("branchPullRequest")
            ]
            result["pr_links"] = [link for link in links if link]
            result["latest_run"] = (
                max(runs, key=lambda r: r["ordinal"]) if runs else None
            )
            result["limit_recovery"] = projection.get("quota_recovery_eligible", False)
            messages = [
                m
                for m in projection.get("messages", [])
                if m["role"] == "assistant" and not m.get("streaming")
            ]
            result["latest_reply"] = messages[-1]["text"][-10000:] if messages else ""
        return result

    def stop(self, args):
        task = self.store.task(text(args.get("task_key"), 100))
        command = self.store.reserve("stop:" + text(args.get("request_id"), 100), args)
        if (
            task["last_status"] in {"launching", "uncertain_launch"}
            and not task["thread_id"]
        ):
            # Do not start new work to discover the result of an uncertain launch.
            self.store.db.execute(
                "UPDATE tasks SET last_status='uncertain_launch' WHERE task_key=?",
                (task["task_key"],),
            )
            self.store.db.commit()
            raise ValueError(
                "Launch result uncertain: stopped retries. Check the existing T3 worktree before cancelling manually."
            )
        if task["thread_id"] and task["last_status"] not in {
            "queued",
            "waiting_quota",
            "stopped",
        }:
            self.store.db.execute(
                "UPDATE tasks SET last_status='stopping', stop_command=? WHERE task_key=?",
                (command, task["task_key"]),
            )
            self.store.db.commit()
            self.rpc(
                "orchestration.dispatchCommand",
                {
                    "type": "thread.stop",
                    "commandId": command,
                    "threadId": task["thread_id"],
                    "reason": "Stopped by Hugo through Ciel",
                    "stopDelegatedTasks": True,
                },
            )
        self.store.db.execute(
            "UPDATE tasks SET last_status='stopped' WHERE task_key=?",
            (task["task_key"],),
        )
        self.store.db.commit()
        return self.summary(self.store.task(task["task_key"]))

    def reply(self, args):
        task = self.store.task(text(args.get("task_key"), 100))
        if not task["thread_id"] or task["last_status"] in {
            "queued",
            "waiting_quota",
            "stopped",
            "stopping",
        }:
            raise ValueError("Task has no active T3 conversation")
        if self.other_active(task["task_key"]):
            raise ValueError(
                "Another coding task is active; wait before resuming this task"
            )
        message = text(args.get("message"))
        command = self.store.reserve("reply:" + text(args.get("request_id"), 100), args)
        result = self.rpc(
            "orchestration.dispatchCommand",
            {
                "type": "message.dispatch",
                "commandId": command,
                "threadId": task["thread_id"],
                "messageId": str(uuid.uuid5(uuid.NAMESPACE_URL, command)),
                "text": message,
                "attachments": [],
                "dispatchMode": {"type": "queue_after_active"},
            },
        )
        self.store.db.execute(
            "UPDATE tasks SET last_status='preparing' WHERE task_key=?",
            (task["task_key"],),
        )
        self.store.db.commit()
        return result

    def other_active(self, key):
        others = self.store.db.execute(
            "SELECT task_key,last_status FROM tasks WHERE task_key!=?", (key,)
        ).fetchall()
        return any(
            r["last_status"]
            not in TERMINAL | {"queued", "waiting_quota", "waiting_followup"}
            for r in others
        )

    def launch(self, task):
        result = self.rpc("orchestration.launchThread", json.loads(task["payload"]))
        self.store.db.execute(
            "UPDATE tasks SET thread_id=?, thread_link=?, last_status='preparing' WHERE task_key=?",
            (result["threadId"], result.get("link"), task["task_key"]),
        )
        self.store.db.commit()

    def tick(self):
        rows = self.store.db.execute("SELECT * FROM tasks ORDER BY rowid").fetchall()
        active = False
        for row in rows:
            task = dict(row)
            if task["last_status"] == "uncertain_launch":
                active = True
                continue
            if task["last_status"] == "stopping":
                self.rpc(
                    "orchestration.dispatchCommand",
                    {
                        "type": "thread.stop",
                        "commandId": task["stop_command"],
                        "threadId": task["thread_id"],
                        "reason": "Stopped by Hugo through Ciel",
                        "stopDelegatedTasks": True,
                    },
                )
                self.store.db.execute(
                    "UPDATE tasks SET last_status='stopped' WHERE task_key=?",
                    (task["task_key"],),
                )
                self.store.db.commit()
                continue
            if (
                task["last_status"] == "ready"
                and time.monotonic() - self.ready_checked.get(task["task_key"], 0) < 300
            ):
                continue
            if (
                task["last_status"] in TERMINAL and task["last_status"] != "ready"
            ) or task["last_status"] in {
                "queued",
                "waiting_quota",
            }:
                continue
            # launchThread has server receipts: retry exactly the stored operation after a lost reply.
            if task["last_status"] == "launching":
                self.launch(task)
                task = self.store.task(task["task_key"])
            state = self.status(task["task_key"])
            from quota_recovery import recover

            if recover(self, task, state):
                active = True
                continue
            status = state.get("agent_status", state["status"])
            verdict = None
            if status == "completed":
                try:
                    project_id = json.loads(task["payload"])["projectId"]
                    verdict = verify(self.rpc, project_id, state.get("pr_links", []))
                except Exception:
                    verdict = {
                        "state": "unverified",
                        "reason": "PR/CI-Status konnte nicht unabhängig über die Forge abgerufen werden.",
                    }
                deferred = verdict["state"] in {
                    "missing",
                    "failed",
                } and self.other_active(task["task_key"])
                if (
                    not deferred
                    and verdict["state"] in {"missing", "failed"}
                    and request_followup(self, task, state, verdict["reason"])
                ):
                    active = True
                    continue
                status = {
                    "ready": "ready",
                    "merged": "merged",
                    "pending": "verifying",
                }.get(verdict["state"], "needs_user")
                if deferred:
                    status = "waiting_followup"
                if status == "ready":
                    self.ready_checked[task["task_key"]] = time.monotonic()
                self.store.db.execute(
                    "UPDATE tasks SET verification=? WHERE task_key=?",
                    (json.dumps(verdict), task["task_key"]),
                )
                self.store.db.commit()
            if status != task["last_status"] or (
                verdict is not None and verdict != state["verification"]
            ):
                self.store.db.execute(
                    "UPDATE tasks SET last_status=? WHERE task_key=?",
                    (status, task["task_key"]),
                )
                if status in TERMINAL or status == "waiting":
                    body = f"T3-Auftrag {task['task_key']}: {status}\n{state['url']}\n{state.get('latest_reply', '')[-8000:]}"
                    if verdict is not None:
                        body += "\nUnabhängige PR-Prüfung: " + json.dumps(
                            verdict, ensure_ascii=False
                        )
                    self.store.db.execute(
                        "INSERT INTO notices(task_key,room_id,body) VALUES(?,?,?)",
                        (task["task_key"], task["room_id"], body),
                    )
                self.store.db.commit()
            active |= status not in TERMINAL
        # Unknown subscription quota: one concurrent coding run, not guessed capacity.
        if not active:
            queued = self.store.db.execute(
                "SELECT * FROM tasks WHERE last_status IN ('queued','waiting_quota') ORDER BY rowid LIMIT 1"
            ).fetchone()
            if queued:
                payload = json.loads(queued["payload"])
                if not any(p["id"] == payload["projectId"] for p in self.projects()):
                    raise ValueError("Queued task's project is no longer authorized")
                config_event = self.rpc(
                    "subscribeServerConfig",
                    {
                        "usageLimitsCommand": True,
                        "usageLimitSources": True,
                        "workspaceSnapshotsOnDemand": True,
                    },
                    first=True,
                )
                tier = next(
                    (
                        name
                        for name, route in self.config["routes"].items()
                        if route["model"] == payload["modelSelection"]["model"]
                        and route["effort"]
                        == next(
                            (
                                option["value"]
                                for option in payload["modelSelection"].get(
                                    "options", []
                                )
                                if option["id"] == "reasoningEffort"
                            ),
                            None,
                        )
                    ),
                    "standard",
                )
                selected = select_provider(
                    config_event.get("config", {}).get("providers", []),
                    tier,
                    self.config["routes"],
                )
                if selected is None:
                    if queued["last_status"] != "waiting_quota":
                        self.store.db.execute(
                            "UPDATE tasks SET last_status='waiting_quota' WHERE task_key=?",
                            (queued["task_key"],),
                        )
                        self.store.db.execute(
                            "INSERT INTO notices(task_key,room_id,body) VALUES(?,?,?)",
                            (
                                queued["task_key"],
                                queued["room_id"],
                                "Ciel-Auftrag wartet: Keines der freigegebenen Abos ist bereit. Ich nutze keine kostenpflichtige API und prüfe später erneut.",
                            ),
                        )
                        self.store.db.commit()
                    return
                payload["modelSelection"] = selected
                self.store.db.execute(
                    "UPDATE tasks SET last_status='launching', payload=? WHERE task_key=?",
                    (json.dumps(payload), queued["task_key"]),
                )
                self.store.db.commit()
                self.launch(self.store.task(queued["task_key"]))

    def handle(self, operation, args):
        if operation == "projects":
            return self.projects()
        if operation == "start":
            return self.start(args)
        if operation == "status":
            return self.status(text(args.get("task_key"), 100))
        if operation == "stop":
            return self.stop(args)
        if operation == "reply":
            return self.reply(args)
        if operation == "notices":
            self.tick()
            return [
                dict(r)
                for r in self.store.db.execute(
                    "SELECT id,room_id,body FROM notices WHERE delivered=0 ORDER BY id LIMIT 10"
                )
            ]
        if operation == "ack":
            self.store.db.execute(
                "UPDATE notices SET delivered=1 WHERE id=?", (int(args["id"]),)
            )
            self.store.db.commit()
            return {"acknowledged": True}
        raise ValueError("Unknown Ciel broker operation")
