"""Task events, one per meaningful state, in plain German with what is still unchecked.

The text first reaches Ciel as an internal event and only falls back to Hugo
verbatim, so it stays short: no JSON dumps, no tool output. Details remain
available through ciel_task_status and ciel_task_history.
"""

HEADLINES = {
    "verifying": "Agent-Lauf beendet, PR-Prüfung steht aus (noch kein Ergebnis, nicht grün)",
    "completed": "Agent-Lauf beendet (Nur-Lesen-Test, kein PR erwartet)",
    "ready": "PR grün auf dem geprüften Head, noch nicht gemergt",
    "merged": "PR ist gemergt",
    "needs_user": "Hugos Entscheidung ist nötig",
    "failed": "Agent-Lauf fehlgeschlagen",
    "waiting": "wartet auf eine Freigabe in T3 (Ciel kann sie nicht erteilen)",
    "interrupted": "Agent-Lauf wurde unterbrochen",
    "cancelled": "Agent-Lauf wurde abgebrochen",
    "rolled_back": "Änderungen wurden zurückgerollt",
}


def fenced(value):
    """Worker-controlled text in an event: it can never close the fence around it."""
    return str(value).replace("<", "‹").replace(">", "›")


# A finished agent run says nothing about the PR. Name what is still open.
PENDING = {
    "missing": "kein PR verknüpft",
    "failed": "CI, Review oder Merge-Status melden ein Problem",
    "pending": "CI-Checks oder Merge-Status stehen noch aus",
    "unverified": "PR/CI konnte nicht unabhängig bestätigt werden",
}


def format_notice(task, state, status, verdict):
    lines = [f"T3-Auftrag {task['task_key']}: {HEADLINES.get(status, status)}."]
    if state.get("url"):
        lines.append(state["url"])
    for link in state.get("pr_links", []):
        lines.append("PR: " + fenced(link.get("url", link)))
    if verdict is not None:
        checked = verdict.get("checked") or []
        if checked:
            lines.append(
                "Geprüfter Head: "
                + ", ".join(str(p.get("head", "?"))[:12] for p in checked)
            )
        if verdict["state"] == "not_required":
            lines.append(
                "Kein PR, Commit oder CI verlangt, daher nichts davon geprüft; "
                "das Ergebnis ist die Worker-Antwort unten und unbestätigt."
            )
        if verdict["state"] in PENDING:
            reason = verdict.get("reason")
            lines.append(
                "Noch offen: "
                + PENDING[verdict["state"]]
                + (f" ({reason})" if reason else "")
            )
    elif status == "verifying":
        lines.append(
            "Die Forge-Prüfung läuft getrennt; ihr Ergebnis folgt als eigenes Ereignis."
        )
    elif status in {"failed", "interrupted", "cancelled", "waiting"}:
        lines.append("Kein Ergebnis geprüft; der Worktree bleibt erhalten.")
    reply = (state.get("latest_reply") or "").strip()
    if reply:
        # The worker's own summary, shortened; it is a claim, not evidence.
        # Fenced: the worker cannot close the tag and speak as Hugo.
        excerpt = fenced(reply[-1200:])
        lines.append(
            "Letzte Worker-Antwort (Auszug, unbestätigt):\n<worker_report>\n"
            + excerpt
            + "\n</worker_report>"
        )
    return "\n".join(lines)


def event_key(task, status, state, verdict):
    run = (state.get("latest_run") or {}).get("id", "")
    return ":".join(
        [task["task_key"], status, str(run), (verdict or {}).get("state", "")]
    )
