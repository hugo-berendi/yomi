"""Mark a T3 thread solved only on fresh evidence, never because an agent stopped.

Solved means: the run finished, nothing is pending, and the forge shows the PR
merged, or green on its exact head with an approving review. A stopped task
stays stopped. Activation is Hugo's step and is never inferred.
"""

import json

from pr_verification import verify
from task_policy import READONLY

# What a broker state means for Hugo, kept apart from "solved".
STAGES = {
    "queued": "wartet auf Start",
    "waiting_quota": "wartet auf freies Abo",
    "launching": "startet",
    "uncertain_launch": "Start unbestätigt",
    "preparing": "läuft",
    "running": "läuft",
    "waiting": "wartet auf Eingabe",
    "waiting_followup": "Implementierung fertig, Nacharbeit wartet auf Slot",
    "verifying": "Implementierung fertig, PR-Prüfung läuft",
    "completed": "Lauf beendet, kein PR erwartet (Nur-Lesen-Test)",
    "ready": "PR reviewbereit, nicht gemergt",
    "merged": "gemergt, Aktivierung nicht beobachtet",
    "needs_user": "wartet auf Hugos Entscheidung",
    "stopped": "gestoppt",
    "stopping": "wird gestoppt",
    "failed": "fehlgeschlagen",
    "interrupted": "unterbrochen",
    "cancelled": "abgebrochen",
    "quota_paused": "pausiert (Kontingent)",
}


def blockers(dispatcher, task, state, verdict):
    found = []
    run = state.get("latest_run") or {}
    if run.get("status") != "completed":
        found.append(f"letzter Lauf ist nicht abgeschlossen ({run.get('status')})")
    if state.get("pending_requests") or dispatcher_open(dispatcher, task):
        found.append("offene Rückfrage")
    if task.get("pending_command"):
        found.append("eine Folgenachricht ist noch nicht verarbeitet")
    if verdict["state"] == "merged":
        return found
    if verdict["state"] != "ready":
        found.append(
            "PR nicht nachweislich grün: " + verdict.get("reason", verdict["state"])
        )
    elif any(p.get("review") != "approved" for p in verdict.get("checked", [])):
        found.append("PR ist grün, aber keine freigebende Review nachgewiesen")
    return found


def dispatcher_open(dispatcher, task):
    import task_requests

    return task_requests.has_open(dispatcher, task["task_key"])


def solve(dispatcher, args):
    from dispatch_core import text

    key = text(args.get("task_key"), 100)
    operation = "solve:" + text(args.get("request_id"), 100)
    task = dispatcher.store.task(key)
    if task["last_status"] in {"stopped", "stopping"}:
        raise ValueError("Der Auftrag wurde bewusst gestoppt und bleibt gestoppt")
    if not task["thread_id"]:
        raise ValueError("Der Auftrag hat noch keinen T3-Thread")
    if task.get("intent") == READONLY:
        return {
            "task_key": key,
            "solved": False,
            "stage": STAGES.get(task["last_status"], task["last_status"]),
            "blockers": ["Nur-Lesen-Test ohne PR: es gibt keinen Nachweis zu prüfen"],
        }
    state = dispatcher.status(key)
    if state.get("settled"):
        return {"task_key": key, "solved": True, "already": True}
    verdict = verify(
        dispatcher.rpc,
        json.loads(task["payload"])["projectId"],
        state.get("pr_links", []),
    )
    found = blockers(dispatcher, task, state, verdict)
    if found:
        return {
            "task_key": key,
            "solved": False,
            "stage": STAGES.get(task["last_status"], task["last_status"]),
            "blockers": found,
        }
    command = dispatcher.store.reserve(operation, {"task_key": key})
    dispatcher.rpc(
        "thread.settle", {"threadId": task["thread_id"], "commandId": command}
    )
    confirmed = dispatcher.status(key).get("settled", False)
    return {
        "task_key": key,
        "solved": confirmed,
        "evidence": verdict.get("checked"),
        "stage": "gemergt"
        if verdict["state"] == "merged"
        else "PR grün und freigegeben, nicht gemergt",
    }
