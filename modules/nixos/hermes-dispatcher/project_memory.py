"""Registered project preferences, read when a queued task actually starts."""

import json
import re
from datetime import date
from pathlib import Path

WORD = re.compile(r"[a-zäöüß][a-zäöüß0-9-]{4,}", re.I)


def _words(text):
    return {w.lower() for w in WORD.findall(text or "")}


def relevant(entry, description, today=None):
    """Whether a preference belongs in this task's prompt.

    `topics` (optional list) names words of the task that make the entry apply,
    "*" means every task;
    `expires` (optional ISO date) retires a one-off. An entry with neither is
    included only when the task text shares at least two distinctive words with it,
    so an old one-off cannot ride along into unrelated work.
    """
    expires = entry.get("expires")
    if isinstance(expires, str) and expires < (today or date.today()).isoformat():
        return False
    topics = entry.get("topics")
    task = _words(description)
    if isinstance(topics, list) and topics:
        names = {str(t).lower() for t in topics}
        return "*" in names or bool(task & names)
    return len(task & _words(entry["fact"])) >= 2


def project_facts(config, description="", maximum=6000):
    directory = config.get("memoryDirectory")
    if not directory:
        return ""
    try:
        entries = json.loads((Path(directory) / "projects.json").read_text())
    except (OSError, ValueError):
        return ""
    lines = []
    for entry in entries if isinstance(entries, list) else []:
        if (
            isinstance(entry, dict)
            and all(
                isinstance(entry.get(k), str) and entry[k]
                for k in ("fact", "source", "date")
            )
            and relevant(entry, description)
        ):
            lines.append(f"- {entry['fact']} ({entry['source']}, {entry['date']})")
    return "\n".join(lines)[:maximum]
