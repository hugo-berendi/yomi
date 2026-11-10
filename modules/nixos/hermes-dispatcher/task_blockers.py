"""Blockers only Hugo can lift: signing, permission, quota and decisions.

A finished run that reports one is parked as `needs_user` with a fingerprint.
Polling, restarts and unchanged forge evidence reproduce the same fingerprint, so
they queue no second notice and start no run. Only an explicit reply naming the
fingerprint lifts the block, once. Worker text can raise a block but never lift it.
"""

import hashlib
import re

# Checked in order; the first kind that matches wins.
PATTERNS = (
    (
        "signing",
        r"gpg|secret key|signing key|signing failed|smartcard|yubikey|pinentry|"
        r"signed commit|commit signing|signier|geheimer schl",
    ),
    (
        "permission",
        r"permission denied|not authori[sz]ed|requires? (?:your )?approval|"
        r"approval required|freigabe|berechtigung",
    ),
    ("quota", r"usage limit|quota|rate limit|kontingent"),
    (
        "decision",
        r"need(?:s)? (?:your|hugo'?s) (?:decision|input|answer)|waiting for (?:hugo|you)|"
        r"entscheidung|blocked on (?:the )?user",
    ),
)

# Signing happens on amaterasu only (smartcard). Inari never holds the key, so a
# missing secret key there is expected and not something to retry or to repair.
SIGNING_POLICY = (
    "Signiert wird nur auf amaterasu (Smartcard), nie auf inari. Auf inari fehlt der "
    "Schlüssel erwartungsgemäß: kein Karten- oder Agent-Forwarding, kein PIN-Versuch, "
    "kein unsignierter Commit, Signierung nicht abgeschaltet."
)
NEXT_STEP = {
    "signing": SIGNING_POLICY
    + " Der Worktree samt Diff bleibt unverändert; die Übergabe zum Signieren auf "
    "amaterasu ist Hugos Schritt.",
    "permission": "Ciel kann keine Freigabe erteilen; sie kommt von Hugo in T3.",
    "quota": "Das Abo-Kontingent entscheidet Hugo; keine kostenpflichtige API.",
    "decision": "Hugo muss eine Entscheidung treffen.",
}


def detect(reply, signing=True):
    """(kind, fingerprint) for a reported blocker, else None. Case and digits are ignored."""
    text = (reply or "").lower()
    for kind, pattern in PATTERNS:
        if kind == "signing" and not signing:
            continue  # inari commits unsigned by Hugo's standing permission
        hits = sorted(set(re.findall(pattern, text)))
        if hits:
            digest = hashlib.sha256((kind + "|" + "|".join(hits)).encode()).hexdigest()
            return kind, digest[:16]
    return None


def park(dispatcher, task, found):
    """Persist the block and notify once per changed fingerprint. Idempotent."""
    kind, fingerprint = found
    generation = task.get("blocked_generation") or 0
    if task.get("blocked_fingerprint") == fingerprint and task["last_status"] == (
        "needs_user"
    ):
        return False
    # Notice first: its dedup key makes a crash between the two writes harmless.
    dispatcher.store.notify(
        task,
        f"{task['task_key']}:blocked:{generation}:{fingerprint}",
        f"T3-Auftrag {task['task_key']}: blockiert ({kind}). {NEXT_STEP[kind]} "
        f"Ciel startet keine Fortsetzung, bis Hugo ausdrücklich antwortet "
        f"(ciel_task_reply mit authorizes_blocker={fingerprint}).",
    )
    dispatcher.store.db.execute(
        "UPDATE tasks SET last_status='needs_user', blocked_kind=?, blocked_fingerprint=?, "
        "pending_command=NULL WHERE task_key=?",
        (kind, fingerprint, task["task_key"]),
    )
    dispatcher.store.db.commit()
    return True


def gate(task, args):
    """Refuse a reply to a blocked task unless it names the current fingerprint."""
    fingerprint = task.get("blocked_fingerprint")
    if fingerprint and args.get("authorizes_blocker") != fingerprint:
        raise ValueError(
            f"Der Auftrag ist blockiert ({task.get('blocked_kind')}); nichts gesendet. "
            f"Nur Hugos ausdrückliche Antwort hebt das auf: authorizes_blocker={fingerprint}."
        )
    return fingerprint
