"""Write yomi's managed blocks into agent harnesses' global instruction files.

Usage: install-instructions.py HOME MANIFEST

MANIFEST is JSON: {"files": {"<path under HOME>": [{"name", "text"}, ...]},
"legacy": ["<marker name>", ...]}. Every `YOMI <name>` block and every legacy
block is removed, and the current blocks are written where the first of them
stood (or at the end). Text outside the blocks belongs to the user and stays.
A file that lists no blocks loses its old ones, so a deleted policy disappears.
"""

import json
import os
import re
import sys
from pathlib import Path

YOMI = r"YOMI [a-z0-9-]+"


def render(block):
    name = "YOMI " + block["name"]
    return f"<!-- BEGIN {name} -->\n{block['text'].strip()}\n<!-- END {name} -->"


def update(old, blocks, legacy):
    names = "|".join([YOMI, *map(re.escape, legacy)])
    pattern = re.compile(rf"<!-- BEGIN ({names}) -->\n.*?<!-- END \1 -->\n*", re.S)
    first = pattern.search(old)
    at = first.start() if first else len(old)
    head, tail = old[:at], pattern.sub("", old[at:])
    leftover = re.search(rf"<!-- (BEGIN|END) ({names}) -->", head + tail)
    if leftover:
        raise ValueError(f"unmatched marker {leftover.group(0)!r}")
    parts = [head.rstrip("\n"), "\n\n".join(map(render, blocks)), tail.strip("\n")]
    parts = [p for p in parts if p]
    return "\n\n".join(parts) + "\n" if parts else ""


def write(path, text):
    mode = path.stat().st_mode & 0o777 if path.exists() else 0o644
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".yomi-new")
    tmp.write_text(text)
    tmp.chmod(mode)
    os.replace(tmp, path)


def main(home, manifest):
    for relative, blocks in manifest["files"].items():
        path = home / relative
        old = path.read_text() if path.exists() else ""
        try:
            new = update(old, blocks, manifest.get("legacy", []))
        except ValueError as error:
            sys.exit(f"{path}: {error}; fix the file by hand and run again")
        if new != old and (path.exists() or blocks):
            write(path, new)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__.strip().splitlines()[2])
    main(Path(sys.argv[1]), json.loads(Path(sys.argv[2]).read_text()))
