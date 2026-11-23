"""Preserve unrelated user preferences while installing requested agent routing."""

import os
from pathlib import Path
import sys
import tomlkit

home = Path(sys.argv[1])
policy = Path(sys.argv[2]).read_text()
begin = "<!-- BEGIN INARI EFFICIENT DELEGATION -->"
end = "<!-- END INARI EFFICIENT DELEGATION -->"


def atomic_write(path, content, mode=0o644):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".inari-routing-new")
    tmp.write_text(content)
    tmp.chmod(mode)
    os.replace(tmp, path)


for rel in [".codex/AGENTS.md", ".claude/CLAUDE.md", ".config/opencode/AGENTS.md"]:
    path = home / rel
    old = path.read_text() if path.exists() else ""
    block = begin + "\n" + policy.rstrip() + "\n" + end
    if begin in old:
        first, rest = old.split(begin, 1)
        if end not in rest:
            raise RuntimeError("Incomplete managed routing block: " + rel)
        _, last = rest.split(end, 1)
        new = first + block + last
    else:
        new = old.rstrip() + ("\n\n" if old.strip() else "") + block + "\n"
    if new != old:
        atomic_write(path, new)

# Codex intentionally refuses symlinked sensitive role files.
atomic_write(
    home / ".codex/agents/fast-task.toml", Path(sys.argv[3]).read_text(), 0o600
)

path = home / ".codex/config.toml"
old = path.read_text() if path.exists() else ""
doc = tomlkit.parse(old)
agents = doc.setdefault("agents", tomlkit.table())
agents["enabled"] = True
agents["default_subagent_model"] = "gpt-6-luna"
agents["default_subagent_reasoning_effort"] = "low"
agents.setdefault("max_concurrent_threads_per_session", 2)
agents.setdefault("max_depth", 1)
agents["fast_task"] = {
    "description": "Cheap bounded lookup, triage, mechanical change or targeted test.",
    "config_file": str(home / ".codex/agents/fast-task.toml"),
}
new = tomlkit.dumps(doc)
if new != old:
    atomic_write(path, new, 0o600)
print("Efficient agent routing installed; main models and other preferences retained.")
