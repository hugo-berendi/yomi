"""Quota handoff stays in the same T3 thread/worktree with idempotent messages."""

import json
import uuid
from provider_policy import exhausted, known_available, select_provider


def pause(dispatcher, task, reason):
    if task["last_status"] != "quota_paused":
        dispatcher.store.db.execute(
            "UPDATE tasks SET last_status='quota_paused' WHERE task_key=?",
            (task["task_key"],),
        )
        dispatcher.store.db.execute(
            "INSERT INTO notices(task_key,room_id,body) VALUES(?,?,?)",
            (task["task_key"], task["room_id"], reason),
        )
        dispatcher.store.db.commit()
    return True


def recover(dispatcher, task, state):
    if task.get("recovery"):
        return continue_handoff(dispatcher, task, json.loads(task["recovery"]))
    run = state.get("latest_run")
    status = state.get("agent_status", state["status"])
    if not run or status not in {"failed", "waiting"}:
        return False
    if status == "waiting" and not state.get("limit_recovery"):
        return False  # a request for Hugo's decision must never be bypassed
    event = dispatcher.rpc(
        "subscribeServerConfig",
        {
            "usageLimitsCommand": True,
            "usageLimitSources": True,
            "workspaceSnapshotsOnDemand": True,
        },
        first=True,
    )
    providers = event.get("config", {}).get("providers", [])
    current = run.get("providerInstanceId")
    selection = None
    if not any(p["instanceId"] == current and exhausted(p) for p in providers):
        if task["last_status"] != "quota_paused":
            return False
        if any(p["instanceId"] == current and known_available(p) for p in providers):
            selection = run["modelSelection"]
        else:
            return pause(
                dispatcher,
                task,
                "Kontingent weiterhin unbekannt oder erschöpft; der Auftrag bleibt erhalten und wartet.",
            )
    prefix = "quota:" + task["task_key"] + ":"
    key = prefix + run["id"]
    previous = dispatcher.store.db.execute(
        "SELECT COUNT(*) FROM commands WHERE substr(operation_key,1,?)=?",
        (len(prefix), prefix),
    ).fetchone()[0]
    if previous >= 2:
        return pause(
            dispatcher,
            task,
            "Der Auftrag wartet nach zwei automatischen Abo-Fortsetzungen. Bitte entscheide, ob Ciel weiterarbeiten soll.",
        )
    selection = selection or select_provider(
        [p for p in providers if p["instanceId"] != current],
        "standard",
        dispatcher.config["routes"],
    )
    if selection is None:
        return pause(
            dispatcher,
            task,
            "Die vorhandenen Abos haben aktuell kein nutzbares Kontingent. Der Auftrag pausiert; keine kostenpflichtige API wird genutzt.",
        )
    args = {"thread_id": task["thread_id"], "run_id": run["id"], "selection": selection}
    command = dispatcher.store.reserve(key, args)
    intent = {"command": command, "selection": selection}
    dispatcher.store.db.execute(
        "UPDATE tasks SET recovery=? WHERE task_key=?",
        (json.dumps(intent), task["task_key"]),
    )
    dispatcher.store.db.commit()
    return continue_handoff(dispatcher, task, intent)


def continue_handoff(dispatcher, task, intent):
    command, selection = intent["command"], intent["selection"]
    dispatcher.rpc(
        "orchestration.dispatchCommand",
        {
            "type": "thread.stop",
            "commandId": command + ":stop",
            "threadId": task["thread_id"],
            "reason": "Confirmed subscription quota handoff",
            "stopDelegatedTasks": True,
        },
    )
    original = json.loads(task["payload"])["initialMessage"]["text"]
    dispatcher.rpc(
        "orchestration.dispatchCommand",
        {
            "type": "message.dispatch",
            "commandId": command,
            "threadId": task["thread_id"],
            "messageId": str(uuid.uuid5(uuid.NAMESPACE_URL, command)),
            "modelSelection": selection,
            "dispatchMode": {"type": "queue_after_active"},
            "attachments": [],
            "text": "Continue the authorized task after a confirmed subscription quota limit. Keep the existing worktree and inspect the actual current changes before doing more work. Do not duplicate issues or PRs. Original task contract follows:\n"
            + original,
        },
    )
    dispatcher.store.db.execute(
        "UPDATE tasks SET last_status='preparing', recovery=NULL WHERE task_key=?",
        (task["task_key"],),
    )
    dispatcher.store.db.execute(
        "INSERT INTO notices(task_key,room_id,body) VALUES(?,?,?)",
        (
            task["task_key"],
            task["room_id"],
            f"Auftrag {task['task_key']}: Nach bestätigtem Abo-Limit läuft die Fortsetzung im selben T3-Thread mit {selection['model']}.",
        ),
    )
    dispatcher.store.db.commit()
    return True
