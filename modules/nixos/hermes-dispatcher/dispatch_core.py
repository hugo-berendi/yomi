"""Narrow task API: registered projects, owned threads and stable server command IDs."""

import json
import logging
import re
import time
import uuid

from ciel_routing import choose
from task_policy import task_prompt
from provider_policy import codex_selection, exhausted, select_provider
from model_selection import ModelNotEnforced, effort_of, matches, offered, requested
from matrix_rooms import private_room
from pr_verification import verify
from project_memory import project_facts
from task_followup import request_followup
from dispatch_store import WAKE_FALLBACK, command_id
from task_notices import event_key, format_notice
import task_requests as requests
import task_supplements as supplements
from task_solve import STAGES, solve
from task_scheduler import TERMINAL, backoff, blocker, holds_slot, limit

# A follow-up whose run never appears must not hold a slot forever.
FOLLOWUP_GRACE = 900
# Run states in which a newer run may still be about to start.
RUN_DONE = {"completed", "failed", "interrupted", "cancelled", "stopped", "error"}
# Repeated launch failures end in a human decision instead of retrying forever.
LAUNCH_ATTEMPTS = 6
STUCK_NOTICE_AFTER = 6


REQUIRED_TOOLS = {
    "t3_project_list",
    "t3_thread_launch",
    "t3_thread_read",
    "t3_thread_send",
    "t3_thread_interrupt",
    "t3_thread_configure",
    "t3_pending_request",
    "t3_thread_organize",
    "orchestrator_capabilities",
}


def model_label(payload):
    chosen = payload.get("modelSelection") or {}
    return {
        "provider": chosen.get("instanceId"),
        "model": chosen.get("model"),
        "effort": effort_of(chosen),
        "pinned": bool(payload.get("pinned")),
    }


def text(value, maximum=12000):
    if not isinstance(value, str) or not value.strip() or len(value) > maximum:
        raise ValueError("Expected nonempty bounded text")
    return value


def key_list(value):
    if value is None:
        return []
    if not isinstance(value, list) or len(value) > 10:
        raise ValueError("depends_on must be a short list of task keys")
    return [text(v, 100) for v in value]


class Dispatcher:
    def __init__(self, config, store, rpc, verify_room=private_room):
        self.config, self.store, self.rpc = config, store, rpc
        self.verify_room = verify_room
        self.slots = limit(config)

    def projects(self):
        item = self.rpc("orchestration.subscribeShell", {}, first=True)
        if item.get("kind") != "snapshot":
            raise RuntimeError("T3 did not return its project snapshot")
        return [
            {k: p[k] for k in ("id", "title", "workspaceRoot")}
            for p in item["snapshot"]["projects"]
            if p["id"] in self.config["projectIds"] and not p.get("archivedAt")
        ]

    # {{{ Intake
    def start(self, args):
        key = text(args.get("task_key"), 100)
        if not re.fullmatch(r"[a-zA-Z0-9_.:-]+", key):
            raise ValueError("Invalid task key")
        description = text(args.get("description"))
        depends_on = key_list(args.get("depends_on"))
        group = args.get("serial_group")
        if group is not None and not re.fullmatch(
            r"[a-zA-Z0-9_.:-]{1,100}", str(group)
        ):
            raise ValueError("Invalid serial_group")
        if key in depends_on:
            raise ValueError("A task cannot depend on itself")
        room = self.verify_room(self.config, args.get("room_id"))
        # The homeserver already verified membership and encryption. Room v12
        # identifiers have no domain suffix, so a colon is not required.
        if not isinstance(room, str) or not room.startswith("!"):
            raise ValueError(
                "A Matrix room ID is required for private completion delivery"
            )
        project_id = args.get("project_id")
        if not any(p["id"] == project_id for p in self.projects()):
            raise ValueError("Project is not registered and authorized for Ciel")
        known = {
            r["task_key"] for r in self.store.db.execute("SELECT task_key FROM tasks")
        }
        if set(depends_on) - known:
            raise ValueError("depends_on names a task Ciel does not own")
        pinned = requested(self.config, args)
        if pinned and key not in known:
            reason = offered(
                self.rpc("capabilities", {"search": pinned["model"]}), pinned
            )
            if reason:
                raise ValueError(
                    f"Nicht gestartet: {reason} ({pinned['instanceId']}/{pinned['model']}, {effort_of(pinned)})."
                )
        command = self.store.reserve("start:" + key, args)
        if key not in known:
            tier = choose(description)
            selection = self.config["routes"][tier]
            thread_id = str(uuid.uuid5(uuid.NAMESPACE_URL, command))
            payload = {
                "commandId": command,
                "projectId": project_id,
                "title": "Ciel: " + description.splitlines()[0][:100],
                # An explicit choice is never re-routed or substituted later.
                "pinned": pinned is not None,
                "modelSelection": pinned or codex_selection(selection),
                "runtimeMode": "full-access",
                "interactionMode": "default",
                "workspaceStrategy": {
                    "type": "worktree",
                    "baseRef": "HEAD",
                    "branch": "ciel/" + thread_id[:12],
                },
                "initialMessage": {"text": self.prompt(description), "attachments": []},
            }
            self.store.db.execute(
                "INSERT INTO tasks(task_key,payload,thread_id,room_id,last_status,description,depends_on,serial_group) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                (
                    key,
                    json.dumps(payload),
                    None,
                    room,
                    "queued",
                    description,
                    json.dumps(depends_on),
                    group,
                ),
            )
            self.store.db.commit()
        self.advance(key)
        return self.summary(self.store.task(key))

    def prompt(self, description):
        return task_prompt(
            description,
            self.config["taste"],
            self.config.get("globalRules", ""),
            project_facts(self.config),
        )

    # }}}

    # {{{ Reporting
    def tasks(self):
        return self.store.db.execute("SELECT * FROM tasks ORDER BY rowid").fetchall()

    def used(self, rows=None):
        return sum(holds_slot(dict(r)) for r in (rows or self.tasks()))

    def summary(self, task):
        result = {
            "task_key": task["task_key"],
            "status": task["last_status"],
            "broker_state": task["last_status"],
            "verification": json.loads(task["verification"])
            if task.get("verification")
            else None,
            "thread_id": task["thread_id"],
            "url": task.get("thread_link"),
            "observed_at": task.get("observed_at"),
            "last_error": task.get("last_error"),
            "observation_failures": task.get("failures") or 0,
            "stage": STAGES.get(task["last_status"], task["last_status"]),
            "model": model_label(json.loads(task["payload"])),
            "open_requests": [
                r["request"] for r in requests.listing(self, task["task_key"])
            ],
            "pending_supplements": len(supplements.pending(self, task["task_key"])),
        }
        if task["last_status"] in {"queued", "waiting_quota"}:
            result["waiting_on"] = blocker(task, [dict(r) for r in self.tasks()]) or (
                {"kind": "slot", "used": self.used(), "limit": self.slots}
                if self.used() >= self.slots
                else {"kind": "next_scheduler_pass"}
            )
        return result

    def overview(self):
        rows = [dict(r) for r in self.tasks()]
        pending = {
            r["task_key"]: r["n"]
            for r in self.store.db.execute(
                "SELECT task_key, COUNT(*) n FROM notices WHERE delivered=0 GROUP BY task_key"
            )
        }
        stuck = self.store.db.execute(
            "SELECT COUNT(*) FROM notices WHERE delivered=0 AND wake_failed_since IS NOT NULL"
        ).fetchone()[0]
        return {
            "slots": {"used": self.used(rows), "limit": self.slots},
            "delivery": {
                "undelivered": sum(pending.values()),
                "wake_failing": stuck,
            },
            "t3_capabilities": self.capability_gaps(),
            "tasks": [
                {
                    **self.summary(t),
                    "undelivered_notices": pending.get(t["task_key"], 0),
                }
                for t in rows
            ],
        }

    def capability_gaps(self):
        """Name T3 MCP tools the broker relies on but its session is not offered."""
        try:
            offered_tools = set(self.rpc("tools", {}))
        except Exception as exc:
            return {"checked": False, "error": type(exc).__name__}
        return {
            "checked": True,
            "missing": sorted(REQUIRED_TOOLS - offered_tools),
        }

    def history(self, args):
        """One bounded page of a Ciel-owned thread, for reading results on demand."""
        task = self.store.task(text(args.get("task_key"), 100))
        if not task["thread_id"]:
            raise ValueError("Der Auftrag hat noch keinen T3-Thread")
        after = args.get("after_position")
        if after is not None and (not isinstance(after, int) or after < 0):
            raise ValueError("after_position muss eine nichtnegative Zahl sein")
        page = self.rpc(
            "thread.page",
            {
                "threadId": task["thread_id"],
                "afterPosition": after,
                "limit": 10,
                "maxChars": 2000,
            },
        )
        return {
            "task_key": task["task_key"],
            "items": [
                {
                    "position": i.get("position"),
                    "type": i.get("type"),
                    "run_id": i.get("runId"),
                    "text": i.get("text"),
                    "truncated": i.get("textTruncated", False),
                }
                for i in page.get("items", [])
                if i.get("type") in {"user_message", "assistant_message", "plan"}
            ],
            "next_position": page.get("nextPosition"),
            "has_more": page.get("hasMore", False),
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
            latest = max(runs, key=lambda r: r["ordinal"]) if runs else None
            result["status"] = latest["status"] if latest else "preparing"
            result["agent_status"] = result["status"]
            if task.get("pending_command"):
                # A follow-up is accepted, but T3 may still show the previous run.
                # Reading it as the answer would report old work as the new result.
                if latest and latest["ordinal"] > task["baseline_ordinal"]:
                    result["followup_started"] = True
                elif not latest or latest["status"] in RUN_DONE:
                    if time.time() - (task["pending_since"] or 0) > FOLLOWUP_GRACE:
                        result["followup_stalled"] = True
                    else:
                        result["status"] = result["agent_status"] = "preparing"
            if task["last_status"] in {
                "verifying",
                "ready",
                "needs_user",
                "quota_paused",
            }:
                result["status"] = task["last_status"]
            thread = projection.get("thread", {})
            # A run waiting on a question still reports `running`.
            result["pending_requests"] = thread.get("pendingRequestCount", 0) or 0
            result["settled"] = bool(thread.get("settled"))
            links = thread.get("pullRequests") or [
                thread.get("linkedPullRequest") or thread.get("branchPullRequest")
            ]
            result["pr_links"] = [link for link in links if link]
            result["latest_run"] = latest
            result["limit_recovery"] = projection.get("quota_recovery_eligible", False)
            messages = [
                m
                for m in projection.get("messages", [])
                if m["role"] == "assistant" and not m.get("streaming")
            ]
            result["latest_reply"] = messages[-1]["text"][-10000:] if messages else ""
        return result

    # }}}

    # {{{ Operator commands
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
            "UPDATE tasks SET last_status='stopped', pending_command=NULL WHERE task_key=?",
            (task["task_key"],),
        )
        self.store.db.execute(
            "UPDATE supplements SET state='dropped' WHERE task_key=? AND state='pending'",
            (task["task_key"],),
        )
        requests.close(self, task["task_key"], "Auftrag gestoppt")
        return self.summary(self.store.task(task["task_key"]))

    def reply(self, args):
        task = self.store.task(text(args.get("task_key"), 100))
        message = text(args.get("message"))
        key = "reply:" + text(args.get("request_id"), 100)
        if task["last_status"] in {"stopped", "stopping"}:
            raise ValueError("Der Auftrag ist gestoppt; nichts gesendet")
        if not task["thread_id"]:
            if task["last_status"] == "launching":
                # The first prompt is already frozen; a late addition would
                # arrive after the worker started, not before.
                raise ValueError(
                    "Der Auftrag startet gerade; sende die Ergänzung in einer Minute mit derselben request_id erneut"
                )
            if task["last_status"] not in {"queued", "waiting_quota"}:
                # An uncertain launch may own an unknown thread: no new work.
                raise ValueError("Task has no active T3 conversation")
            # Kept durably and folded into the first prompt when the task starts.
            return supplements.add(self, task, key, message)
        if requests.has_open(self, task["task_key"]):
            # A thread message would queue a second run behind the question.
            raise ValueError(
                "Der Auftrag wartet auf eine Rückfrage; beantworte sie mit ciel_task_answer statt einer Nachricht"
            )
        if task["last_status"] in {"queued", "waiting_quota"}:
            raise ValueError("Task has no active T3 conversation")
        # A reply to a running task queues behind its run. Resuming an idle one
        # starts a new run and needs a free slot, so the bound holds for follow-ups too.
        if (
            not self.store.seen(key)
            and not holds_slot(task)
            and self.used() >= self.slots
        ):
            raise ValueError(
                "All coding slots are busy; retry this reply with the same request_id when one frees up"
            )
        payload = json.loads(task["payload"])
        change = requested(self.config, args)
        if change:
            reason = offered(
                self.rpc("capabilities", {"search": change["model"]}), change
            )
            if reason:
                raise ValueError(f"Nichts gesendet: {reason}.")
        elif payload.get("pinned"):
            stored = self.rpc("thread.configuration", {"threadId": task["thread_id"]})
            if not matches(payload["modelSelection"], stored.get("modelSelection")):
                raise ValueError(
                    "Nichts gesendet: Die Thread-Konfiguration weicht vom festgelegten Modell ab. Gib provider, model und effort an, um sie bewusst zu setzen."
                )
        projection = self.rpc(
            "orchestration.getThreadProjection", {"threadId": task["thread_id"]}
        )
        ordinal = max((r["ordinal"] for r in projection["runs"]), default=0)

        def intent(db):
            db.execute(
                "UPDATE tasks SET pending_command=?, baseline_ordinal=?, pending_since=?, failures=0, next_check=NULL WHERE task_key=?",
                (command_id(key), ordinal, time.time(), task["task_key"]),
            )

        command = self.store.reserve(key, args, apply=intent)
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
                **({"modelSelection": change} if change else {}),
            },
        )
        if change:
            # The backend read the stored configuration back before sending.
            payload.update({"pinned": True, "modelSelection": change})
            self.store.db.execute(
                "UPDATE tasks SET payload=? WHERE task_key=?",
                (json.dumps(payload), task["task_key"]),
            )
        self.store.db.execute(
            "UPDATE tasks SET last_status='preparing' WHERE task_key=? AND pending_command=?",
            (task["task_key"], command),
        )
        self.store.db.commit()
        return result

    # }}}

    # {{{ Launching
    def launch(self, task):
        try:
            result = self.rpc("orchestration.launchThread", json.loads(task["payload"]))
        except ModelNotEnforced as exc:
            # The idle thread exists but never received the task. Keep its id so
            # no retry launches a second one, and let Hugo decide.
            self.store.db.execute(
                "UPDATE tasks SET thread_id=?, thread_link=?, last_error=? WHERE task_key=?",
                (exc.thread, exc.link, str(exc), task["task_key"]),
            )
            self.finish(
                task,
                "needs_user",
                "Nicht gestartet: T3 hat die festgelegte Modell-/Effort-Konfiguration nicht übernommen (gespeichert: "
                + json.dumps(
                    (exc.stored or {}).get("modelSelection"), ensure_ascii=False
                )
                + "). Es lief kein Agent.",
            )
            self.store.db.commit()
            return
        self.store.db.execute(
            "UPDATE tasks SET thread_id=?, thread_link=?, last_status='preparing', failures=0, next_check=NULL, last_error=NULL WHERE task_key=?",
            (result["threadId"], result.get("link"), task["task_key"]),
        )
        self.store.db.commit()

    def tier_of(self, payload):
        efforts = {
            o["id"]: o["value"] for o in payload["modelSelection"].get("options", [])
        }
        return next(
            (
                name
                for name, route in self.config["routes"].items()
                if route["model"] == payload["modelSelection"]["model"]
                and route["effort"] == efforts.get("reasoningEffort")
            ),
            "standard",
        )

    def fresh_prompt(self, task, payload):
        """Queued work starts with the preferences recorded while it waited."""
        description = task.get("description")
        if not description:
            found = re.search(
                r"<user_task>\n(.*)\n</user_task>",
                payload["initialMessage"]["text"],
                re.S,
            )
            description = found.group(1) if found else None
        if description:
            payload["initialMessage"]["text"] = self.prompt(description)

    def fill_slots(self, raise_for=None):
        """Start eligible queued tasks, in order, until the slot bound is reached."""
        used = self.used()
        providers = authorized = None
        failure = None
        for row in self.tasks():
            if used >= self.slots:
                break
            task = dict(row)
            if (
                task["last_status"] not in {"queued", "waiting_quota"}
                or task["thread_id"]
            ):
                continue
            reason = blocker(task, [dict(r) for r in self.tasks()])
            if reason:
                if reason["kind"] == "dead":
                    self.store.notify(
                        task,
                        f"{task['task_key']}:dependency:{reason['task']}",
                        f"T3-Auftrag {task['task_key']} bleibt in der Warteschlange: Die Voraussetzung {reason['task']} ist nicht erfolgreich beendet. Entscheide, ob er trotzdem starten oder gestoppt werden soll.",
                    )
                continue
            payload = json.loads(task["payload"])
            if authorized is None:
                authorized = {p["id"] for p in self.projects()}
            if payload["projectId"] not in authorized:
                self.finish(
                    task,
                    "needs_user",
                    "Der Auftrag wurde nicht gestartet: Sein Projekt ist nicht mehr für Ciel freigegeben.",
                )
                continue
            if providers is None:
                providers = (
                    self.rpc(
                        "subscribeServerConfig",
                        {
                            "usageLimitsCommand": True,
                            "usageLimitSources": True,
                            "workspaceSnapshotsOnDemand": True,
                        },
                        first=True,
                    )
                    .get("config", {})
                    .get("providers", [])
                )
            if payload.get("pinned"):
                # Hugo chose this exact configuration: wait for its provider,
                # never fall back to another subscription or model.
                provider = next(
                    (
                        p
                        for p in providers
                        if p.get("instanceId")
                        == payload["modelSelection"]["instanceId"]
                    ),
                    {},
                )
                if (
                    not provider.get("enabled")
                    or not provider.get("installed")
                    or provider.get("status") != "ready"
                    or exhausted(provider)
                ):
                    if task["last_status"] != "waiting_quota":
                        self.store.db.execute(
                            "UPDATE tasks SET last_status='waiting_quota' WHERE task_key=?",
                            (task["task_key"],),
                        )
                        self.store.notify(
                            task,
                            f"{task['task_key']}:waiting_pinned",
                            f"T3-Auftrag {task['task_key']} wartet: Das festgelegte Modell {payload['modelSelection']['model']} ist gerade nicht verfügbar. Ich weiche auf kein anderes Modell aus.",
                        )
                    continue
                selected = payload["modelSelection"]
            else:
                selected = select_provider(
                    providers, self.tier_of(payload), self.config["routes"]
                )
            if selected is None:
                # Every queued task would meet the same exhausted subscriptions.
                if task["last_status"] != "waiting_quota":
                    self.store.db.execute(
                        "UPDATE tasks SET last_status='waiting_quota' WHERE task_key=?",
                        (task["task_key"],),
                    )
                    self.store.notify(
                        task,
                        f"{task['task_key']}:waiting_quota",
                        "Ciel-Auftrag wartet: Keines der freigegebenen Abos ist bereit. Ich nutze keine kostenpflichtige API und prüfe später erneut.",
                    )
                break
            payload["modelSelection"] = selected
            self.fresh_prompt(task, payload)
            supplements.include(self, task, payload)
            self.store.db.execute(
                "UPDATE tasks SET last_status='launching', payload=? WHERE task_key=?",
                (json.dumps(payload), task["task_key"]),
            )
            self.store.db.commit()
            used += 1
            try:
                self.launch(self.store.task(task["task_key"]))
            except Exception as exc:
                self.record_failure(self.store.task(task["task_key"]), exc)
                if task["task_key"] == raise_for:
                    failure = exc
        if failure is not None:
            raise failure

    def advance(self, key=None):
        """Start work now; an explicit request retries its own launch without waiting for backoff."""
        if key:
            task = self.store.task(key)
            if task["last_status"] == "launching" and not task["thread_id"]:
                try:
                    self.launch(task)
                except Exception as exc:
                    self.record_failure(task, exc)
                    raise
        self.fill_slots(raise_for=key)

    def finish(self, task, status, reason):
        self.store.db.execute(
            "UPDATE tasks SET last_status=?, pending_command=NULL WHERE task_key=?",
            (status, task["task_key"]),
        )
        requests.close(self, task["task_key"], "Auftrag beendet: " + status)
        self.store.notify(
            task,
            f"{task['task_key']}:{status}:{reason[:40]}",
            f"T3-Auftrag {task['task_key']}: {reason}",
        )

    # }}}

    # {{{ Observation
    def record_failure(self, task, exc):
        failures = (task.get("failures") or 0) + 1
        error = (
            f"{type(exc).__name__}: {exc}"
            if isinstance(exc, ValueError)
            else type(exc).__name__
        )
        logging.warning(
            "Ciel task %s observation failed (%d): %s",
            task["task_key"],
            failures,
            type(exc).__name__,
        )
        self.store.db.execute(
            "UPDATE tasks SET failures=?, last_error=?, next_check=? WHERE task_key=?",
            (failures, error[:300], time.time() + backoff(failures), task["task_key"]),
        )
        self.store.db.commit()
        if (
            task["last_status"] == "launching"
            and not task["thread_id"]
            and failures >= LAUNCH_ATTEMPTS
        ):
            # Retrying a launch whose receipt cannot be confirmed risks a duplicate worktree.
            self.store.db.execute(
                "UPDATE tasks SET last_status='uncertain_launch' WHERE task_key=?",
                (task["task_key"],),
            )
            self.store.db.commit()
            self.store.notify(
                task,
                f"{task['task_key']}:uncertain_launch",
                f"T3-Auftrag {task['task_key']}: Der Start ließ sich nach {failures} Versuchen nicht bestätigen ({error[:200]}). Ciel startet nichts doppelt; bitte prüfe T3 auf einen vorhandenen Worktree.",
            )
        elif failures == STUCK_NOTICE_AFTER:
            self.store.notify(
                task,
                f"{task['task_key']}:observation-stuck:{error[:60]}",
                f"T3-Auftrag {task['task_key']}: Ciel kann den Zustand seit {failures} Versuchen nicht lesen ({error[:200]}). Der Auftrag ist unverändert; Ciel prüft mit wachsendem Abstand weiter.",
            )

    def observe(self, task):
        if task["last_status"] in {"uncertain_launch", "queued", "waiting_quota"}:
            return
        if task["last_status"] in TERMINAL and task["last_status"] != "ready":
            return
        if task.get("next_check") and task["next_check"] > time.time():
            return
        try:
            self.reconcile(task)
        except Exception as exc:
            self.record_failure(self.store.task(task["task_key"]), exc)
            return
        self.store.db.execute(
            "UPDATE tasks SET observed_at=?, failures=0, last_error=NULL WHERE task_key=?",
            (time.time(), task["task_key"]),
        )
        self.store.db.commit()

    def enforce_pinned(self, task, state):
        """Stop a pinned task whose run T3 started under another provider or model."""
        payload = json.loads(task["payload"])
        run = state.get("latest_run") or {}
        if not payload.get("pinned") or run.get("model") is None:
            return False
        chosen = payload["modelSelection"]
        if (run.get("providerInstanceId"), run.get("model")) == (
            chosen["instanceId"],
            chosen["model"],
        ):
            return False
        command = self.store.reserve(
            "pin-stop:" + task["task_key"] + ":" + str(run.get("id")),
            {"run": run.get("id")},
        )
        self.rpc(
            "orchestration.dispatchCommand",
            {
                "type": "thread.stop",
                "commandId": command,
                "threadId": task["thread_id"],
                "reason": "Run used a different model than Hugo pinned",
                "stopDelegatedTasks": True,
            },
        )
        self.finish(
            task,
            "needs_user",
            f"Gestoppt: Der Lauf nutzte {run.get('providerInstanceId')}/{run.get('model')} statt des festgelegten {chosen['instanceId']}/{chosen['model']}.",
        )
        self.store.db.commit()
        return True

    def reconcile(self, task):
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
            return
        # launchThread has server receipts: retry exactly the stored operation after a lost reply.
        if task["last_status"] == "launching":
            self.launch(task)
            task = self.store.task(task["task_key"])
            if task["last_status"] == "needs_user":
                return
        state = self.status(task["task_key"])
        from quota_recovery import recover

        if state.get("followup_started"):
            self.store.db.execute(
                "UPDATE tasks SET pending_command=NULL, pending_since=NULL WHERE task_key=?",
                (task["task_key"],),
            )
            self.store.db.commit()
            task = self.store.task(task["task_key"])
        if state.get("followup_stalled"):
            self.finish(
                task,
                "needs_user",
                "Die Folgenachricht hat keinen neuen Agent-Lauf gestartet. Bitte prüfe den Thread oder sende sie erneut.",
            )
            self.store.db.commit()
            return
        if self.enforce_pinned(task, state):
            return
        requests.sync(self, task, state)
        if recover(self, task, state):
            return
        status = state.get("agent_status", state["status"])
        if status in {"queued", "waiting_quota"}:
            # T3's own run states must not be mistaken for this broker's queue.
            status = "preparing"
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
            # A repair run needs a slot like any other run.
            deferred = (
                verdict["state"] in {"missing", "failed"} and self.used() >= self.slots
            )
            if (
                not deferred
                and verdict["state"] in {"missing", "failed"}
                and request_followup(self, task, state, verdict["reason"])
            ):
                return
            status = {
                "ready": "ready",
                "merged": "merged",
                "pending": "verifying",
            }.get(verdict["state"], "needs_user")
            if deferred:
                status = "waiting_followup"
            self.store.db.execute(
                "UPDATE tasks SET verification=?, next_check=? WHERE task_key=?",
                (
                    json.dumps(verdict),
                    time.time() + 300 if status == "ready" else None,
                    task["task_key"],
                ),
            )
            self.store.db.commit()
        if status != task["last_status"]:
            self.store.db.execute(
                "UPDATE tasks SET last_status=? WHERE task_key=?",
                (status, task["task_key"]),
            )
            self.store.db.commit()
            if status in TERMINAL:
                # A finished task is not observed again; its questions are moot.
                requests.close(self, task["task_key"], "Auftrag beendet: " + status)
        if status in TERMINAL or status == "waiting":
            self.store.notify(
                task,
                event_key(task, status, state, verdict),
                format_notice(task, state, status, verdict),
            )

    def tick(self):
        """Observe every task independently, then hand freed slots to queued work."""
        for row in self.tasks():
            self.observe(dict(row))
        self.fill_slots()

    # }}}

    def handle(self, operation, args):
        if operation == "projects":
            return self.projects()
        if operation == "start":
            return self.start(args)
        if operation == "status":
            return self.status(text(args.get("task_key"), 100))
        if operation == "tasks":
            return self.overview()
        if operation == "stop":
            return self.stop(args)
        if operation == "reply":
            return self.reply(args)
        if operation == "requests":
            key = args.get("task_key")
            if key is not None:
                self.store.task(text(key, 100))
            return requests.listing(self, key)
        if operation == "answer":
            return requests.answer(self, args)
        if operation == "history":
            return self.history(args)
        if operation == "solve":
            return solve(self, args)
        if operation == "notices":
            cutoff = time.time() - WAKE_FALLBACK
            return [
                {
                    "id": r["id"],
                    "room_id": r["room_id"],
                    "body": r["body"],
                    "task_key": r["task_key"],
                    # Ciel acts on events herself; Hugo gets the text only if
                    # her session cannot be woken for WAKE_FALLBACK seconds.
                    "mode": "text"
                    if r["wake_failed_since"] is not None
                    and r["wake_failed_since"] < cutoff
                    else "wake",
                }
                for r in self.store.db.execute(
                    "SELECT * FROM notices WHERE delivered=0 ORDER BY id LIMIT 10"
                )
            ]
        if operation == "wake_failed":
            self.store.db.execute(
                "UPDATE notices SET wake_failed_since=COALESCE(wake_failed_since, ?) WHERE id=?",
                (time.time(), int(args["id"])),
            )
            self.store.db.commit()
            return {"recorded": True}
        if operation == "ack":
            self.store.db.execute(
                "UPDATE notices SET delivered=1, delivered_as=? WHERE id=?",
                (args.get("as", "text"), int(args["id"])),
            )
            self.store.db.commit()
            return {"acknowledged": True}
        raise ValueError("Unknown Ciel broker operation")
