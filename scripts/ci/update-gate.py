"""Decide whether an automated update commit is safe to merge without review.

Compares HEAD against --base and prints one JSON object
{"ok": bool, "reasons": [...], "summary": [...]}. Exit 0 = ok, 1 = not ok,
2 = internal error (never reported as ok). Everything under review is treated
as data: nothing is evaluated, only parsed and pattern-matched.
"""

import argparse
import difflib
import json
import re
import subprocess
import sys
from urllib.parse import urlparse


MAX_BYTES = 5 * 1024 * 1024
LOCK = "flake.lock"
IMAGES = "hosts/nixos/inari/images.nix"
LOCKED_MUTABLE = {"rev", "narHash", "lastModified", "revCount"}
HASH_ATTRS = {
    "hash",
    "sha256",
    "outputHash",
    "vendorHash",
    "cargoHash",
    "npmDepsHash",
    "pnpmDepsHash",
}
TEXT_ATTRS = {"version", "rev"}
ATTR_LINE = re.compile(
    r"^\s*("
    + "|".join(sorted(HASH_ATTRS | TEXT_ATTRS))
    + r')\s*=\s*"([^"$\\]*)"\s*;\s*$'
)
TEXT_VALUE = re.compile(r"^[A-Za-z0-9._+~-]{1,64}$")
HASH_VALUE = re.compile(
    r"^(sha256-[A-Za-z0-9+/]{43}=|[0-9a-df-np-sv-z]{52}|[0-9a-fA-F]{64})$"
)
IMAGE_LINE = re.compile(
    r'^  ([A-Za-z0-9_-]+) = "([^"$\\\s@]+)@sha256:([0-9a-f]{64})";$'
)


def is_pkg_file(path):
    rest = path[len("pkgs/") :]
    return path.startswith("pkgs/") and "/" not in rest and rest.endswith(".nix")


def changed_lines(old, new):
    """Return (removed, added) lines in diff order."""
    a, b = old.splitlines(), new.splitlines()
    removed, added = [], []
    matcher = difflib.SequenceMatcher(None, a, b, autojunk=False)
    for tag, i1, i2, j1, j2 in matcher.get_opcodes():
        if tag != "equal":
            removed.extend(a[i1:i2])
            added.extend(b[j1:j2])
    return removed, added


def url_parts(url):
    parsed = urlparse(url)
    return parsed.scheme, parsed.hostname


def check_locked(name, old, new):
    reasons = []
    for key in sorted(set(old) | set(new)):
        before, after = old.get(key), new.get(key)
        if key in LOCKED_MUTABLE or before == after:
            continue
        if (
            key == "url"
            and old.get("type") == new.get("type")
            and old.get("type") in ("tarball", "file")
            and isinstance(before, str)
            and isinstance(after, str)
            and url_parts(before) == url_parts(after)
        ):
            continue
        reasons.append(
            f"{LOCK}: {name}: locked.{key} changed ({before!r} -> {after!r})"
        )
    return reasons


def check_lock(old_text, new_text):
    reasons, summary = [], []
    try:
        old, new = json.loads(old_text), json.loads(new_text)
        if old.get("version") != new.get("version"):
            reasons.append(f"{LOCK}: version changed")
        if old.get("root") != new.get("root"):
            reasons.append(f"{LOCK}: root changed")
        for key in sorted((set(old) | set(new)) - {"nodes", "root", "version"}):
            if old.get(key) != new.get(key):
                reasons.append(f"{LOCK}: top-level key {key!r} changed")
        old_nodes, new_nodes = old["nodes"], new["nodes"]
        if set(old_nodes) != set(new_nodes):
            added = sorted(set(new_nodes) - set(old_nodes))
            gone = sorted(set(old_nodes) - set(new_nodes))
            reasons.append(f"{LOCK}: node set changed (added {added}, removed {gone})")
        for name in sorted(set(old_nodes) & set(new_nodes)):
            before, after = old_nodes[name], new_nodes[name]
            others = (set(before) | set(after)) - {"locked"}
            for key in sorted(others):
                if before.get(key) != after.get(key):
                    reasons.append(f"{LOCK}: {name}: {key} changed")
            if ("locked" in before) != ("locked" in after):
                reasons.append(f"{LOCK}: {name}: locked section appeared or vanished")
                continue
            if "locked" not in before:
                continue
            reasons.extend(check_locked(name, before["locked"], after["locked"]))
            if before["locked"] != after["locked"]:
                old_rev, new_rev = (
                    before["locked"].get("rev"),
                    after["locked"].get("rev"),
                )
                if old_rev and new_rev:
                    summary.append(f"{name}: {old_rev[:7]} -> {new_rev[:7]}")
                else:
                    summary.append(f"{name}: updated")
    except (ValueError, KeyError, TypeError, AttributeError) as error:
        reasons.append(f"{LOCK}: unparsable or malformed ({error})")
    return reasons, summary


def check_attr_diff(path, old, new, accept):
    """Allow only paired single-line attribute bumps; accept(name, value) vets values."""
    removed, added = changed_lines(old, new)
    if len(removed) != len(added):
        return [f"{path}: {len(removed)} lines removed but {len(added)} added"], []
    reasons, summary = [], []
    for before, after in zip(removed, added):
        old_m, new_m = accept.pattern.match(before), accept.pattern.match(after)
        if not old_m or not new_m:
            bad = before if not old_m else after
            reasons.append(
                f"{path}: changed line is not an allowed assignment: {bad.strip()!r}"
            )
            continue
        problem = accept.pair(old_m, new_m)
        if problem:
            reasons.append(f"{path}: {problem}")
        else:
            summary.append(accept.describe(path, old_m, new_m))
    return reasons, summary


class Rule:
    """Bundle of the per-file-kind line pattern, pair check and summary text."""

    def __init__(self, pattern, pair, describe):
        self.pattern, self.pair, self.describe = pattern, pair, describe


def pkg_pair(old_m, new_m):
    name, value = new_m.group(1), new_m.group(2)
    if old_m.group(1) != name:
        return f"attribute {old_m.group(1)} paired with {name}"
    pattern = HASH_VALUE if name in HASH_ATTRS else TEXT_VALUE
    if not pattern.match(value):
        return f"{name} has an invalid value {value!r}"
    return None


def pkg_describe(path, old_m, new_m):
    name = new_m.group(1)
    if name in HASH_ATTRS:
        return f"{path}: {name} updated"
    return f"{path}: {name} {old_m.group(2)} -> {new_m.group(2)}"


def image_pair(old_m, new_m):
    if old_m.group(1) != new_m.group(1):
        return f"image {old_m.group(1)} paired with {new_m.group(1)}"
    if old_m.group(2) != new_m.group(2):
        return f"image {new_m.group(1)}: reference changed {old_m.group(2)} -> {new_m.group(2)}"
    return None


def image_describe(path, old_m, new_m):
    return f"{path}: {new_m.group(1)} {old_m.group(3)[:7]} -> {new_m.group(3)[:7]}"


PKG_RULE = Rule(ATTR_LINE, pkg_pair, pkg_describe)
IMAGE_RULE = Rule(IMAGE_LINE, image_pair, image_describe)


def check_changes(entries, read_old, read_new):
    """entries: list of (status, path); read_*: path -> text, ValueError if unreadable."""
    reasons, summary = [], []
    if not entries:
        return ["nothing to merge: no changed paths"], []
    for status, path in sorted(entries, key=lambda e: e[1]):
        if path == LOCK:
            check = check_lock
        elif is_pkg_file(path):
            rule, check = PKG_RULE, None
        elif path == IMAGES:
            rule, check = IMAGE_RULE, None
        else:
            reasons.append(f"{path}: path is not allowed in an automated update")
            continue
        if status != "M":
            reasons.append(f"{path}: must be modified, not status {status}")
            continue
        try:
            old, new = read_old(path), read_new(path)
        except ValueError as error:
            reasons.append(f"{path}: {error}")
            continue
        if check is not None:
            found, notes = check(old, new)
        else:
            found, notes = check_attr_diff(path, old, new, rule)
        reasons.extend(found)
        summary.extend(notes)
    return reasons, summary


def git(*args):
    result = subprocess.run(["git", *args], capture_output=True, check=True)
    return result.stdout


def git_entries(base):
    out = git("diff", "--name-status", "--no-renames", "-z", base, "HEAD")
    parts = out.decode("utf-8", "surrogateescape").split("\0")
    parts = [p for p in parts if p]
    return [(parts[i], parts[i + 1]) for i in range(0, len(parts), 2)]


def git_reader(rev):
    def read(path):
        size = int(git("cat-file", "-s", f"{rev}:{path}"))
        if size > MAX_BYTES:
            raise ValueError(f"file exceeds {MAX_BYTES} bytes")
        try:
            return git("show", f"{rev}:{path}").decode("utf-8")
        except UnicodeDecodeError as error:
            raise ValueError("not valid UTF-8") from error

    return read


def evaluate(base):
    if base.startswith("-"):
        raise ValueError("base must be a git ref, not an option")
    entries = git_entries(base)
    reasons, summary = check_changes(entries, git_reader(base), git_reader("HEAD"))
    return {"ok": not reasons, "reasons": reasons, "summary": summary}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", required=True, help="git ref to compare HEAD against")
    args = parser.parse_args()
    try:
        verdict = evaluate(args.base)
    except Exception as error:  # noqa: BLE001 - any failure must be "not ok", exit 2
        verdict = {"ok": False, "reasons": [f"internal error: {error}"], "summary": []}
        print(json.dumps(verdict))
        return 2
    print(json.dumps(verdict))
    return 0 if verdict["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
