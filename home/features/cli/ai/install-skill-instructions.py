"""Update skill instructions without replacing the user's global instructions."""

from pathlib import Path
import os
import sys

home = Path(sys.argv[1])
policy = Path(sys.argv[2]).read_text().rstrip()
begin = "<!-- BEGIN MANAGED SKILL USAGE -->"
end = "<!-- END MANAGED SKILL USAGE -->"
block = f"{begin}\n{policy}\n{end}"

for rel in [".codex/AGENTS.md", ".claude/CLAUDE.md", ".gemini/GEMINI.md"]:
    path = home / rel
    old = path.read_text() if path.exists() else ""
    if begin in old:
        first, rest = old.split(begin, 1)
        if end not in rest:
            raise RuntimeError("Incomplete managed skill block: " + rel)
        _, last = rest.split(end, 1)
        new = first + block + last
    else:
        new = old.rstrip() + ("\n\n" if old.strip() else "") + block + "\n"
    if new != old:
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_name(path.name + ".skills-new")
        tmp.write_text(new)
        tmp.chmod(path.stat().st_mode & 0o777 if path.exists() else 0o644)
        os.replace(tmp, path)
