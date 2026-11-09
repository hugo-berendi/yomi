"""Registered project preferences, read when a queued task actually starts."""

import json
from pathlib import Path


def project_facts(config, maximum=6000):
    directory = config.get("memoryDirectory")
    if not directory:
        return ""
    try:
        entries = json.loads((Path(directory) / "projects.json").read_text())
    except (OSError, ValueError):
        return ""
    lines = []
    for entry in entries if isinstance(entries, list) else []:
        if isinstance(entry, dict) and all(
            isinstance(entry.get(k), str) and entry[k]
            for k in ("fact", "source", "date")
        ):
            lines.append(f"- {entry['fact']} ({entry['source']}, {entry['date']})")
    return "\n".join(lines)[:maximum]
