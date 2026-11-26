"""Install Codex's fast_task role and subagent defaults, keeping other settings.

Usage: install-codex-agents.py HOME ROLE_TOML MODEL EFFORT
"""

import os
import sys
from pathlib import Path

import tomlkit

home, role, model, effort = Path(sys.argv[1]), Path(sys.argv[2]), *sys.argv[3:5]


def atomic_write(path, content, mode=0o644):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".inari-routing-new")
    tmp.write_text(content)
    tmp.chmod(mode)
    os.replace(tmp, path)


# Codex intentionally refuses symlinked sensitive role files.
atomic_write(home / ".codex/agents/fast-task.toml", role.read_text(), 0o600)

path = home / ".codex/config.toml"
old = path.read_text() if path.exists() else ""
doc = tomlkit.parse(old)
agents = doc.setdefault("agents", tomlkit.table())
agents["enabled"] = True
agents["default_subagent_model"] = model
agents["default_subagent_reasoning_effort"] = effort
agents.setdefault("max_concurrent_threads_per_session", 2)
agents.setdefault("max_depth", 1)
agents["fast_task"] = {
    "description": "Cheap bounded lookup, triage, mechanical change or targeted test.",
    "config_file": str(home / ".codex/agents/fast-task.toml"),
}
new = tomlkit.dumps(doc)
if new != old:
    atomic_write(path, new, 0o600)
print("Codex agent routing installed; main models and other preferences retained.")
