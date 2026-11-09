"""Owner-DM notices: one per meaningful state, with evidence and what is still unchecked."""

import json

HEADLINES = {
    "ready": "Agent-Lauf beendet, PR-Prüfung bestanden (noch nicht gemergt)",
    "merged": "PR ist gemergt",
    "needs_user": "Deine Entscheidung ist nötig",
    "failed": "Agent-Lauf fehlgeschlagen",
    "waiting": "Der Agent wartet auf Eingabe oder Freigabe",
    "interrupted": "Agent-Lauf wurde unterbrochen",
    "cancelled": "Agent-Lauf wurde abgebrochen",
    "rolled_back": "Änderungen wurden zurückgerollt",
}
# A finished agent run says nothing about the PR. Name what is still open.
PENDING = {
    "missing": "kein PR verknüpft",
    "failed": "CI, Review oder Merge-Status melden ein Problem",
    "pending": "CI-Checks oder Merge-Status stehen noch aus",
    "unverified": "PR/CI konnte nicht unabhängig bestätigt werden",
}


def format_notice(task, state, status, verdict):
    lines = [f"T3-Auftrag {task['task_key']}: {HEADLINES.get(status, status)}"]
    run = state.get("latest_run") or {}
    if run:
        lines.append(
            f"Agent-Lauf {run.get('ordinal', '?')}: {state.get('agent_status', state['status'])}"
        )
    if state.get("url"):
        lines.append(state["url"])
    for link in state.get("pr_links", []):
        lines.append("PR: " + str(link.get("url", link)))
    if verdict is not None:
        lines.append(
            "Unabhängige PR-Prüfung: "
            + json.dumps(verdict, ensure_ascii=False, sort_keys=True)
        )
        if verdict["state"] in PENDING:
            lines.append("Noch offen: " + PENDING[verdict["state"]])
    elif status in {"failed", "interrupted", "cancelled", "waiting"}:
        lines.append("Noch offen: kein Ergebnis geprüft; der Worktree bleibt erhalten.")
    lines.append(
        "Hinweis: Ein beendeter Agent-Lauf ist kein verifiziertes Ergebnis."
        if status not in {"ready", "merged"}
        else "Geprüft über die Forge für genau diesen PR-Head."
    )
    reply = state.get("latest_reply", "")[-4000:]
    if reply:
        lines.append("Letzte Antwort des Agenten:\n" + reply)
    return "\n".join(lines)


def event_key(task, status, state, verdict):
    run = (state.get("latest_run") or {}).get("id", "")
    return ":".join(
        [task["task_key"], status, str(run), (verdict or {}).get("state", "")]
    )
