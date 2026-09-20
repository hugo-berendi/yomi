"""Move home persistence data into the gnu/stow-style per-app storage layout.

Impermanence v2 dropped `removePrefixDirectory`
(https://github.com/nix-community/impermanence/issues/287), so the per-app
grouping is now produced by giving every app its own `persistentStoragePath`.
The data already on disk still sits in the flat layout, and a bind mount whose
source does not exist yet comes up empty, so the files have to be moved before
the next switch.

Run this on the host itself. Nothing is touched without `--apply`.
"""

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


def evaluate(host):
    """Read the persistence entries the flake actually produces for `host`."""
    result = subprocess.run(
        [
            "nix",
            "eval",
            "--json",
            f".#nixosConfigurations.{host}.config.home-manager.users",
            "--apply",
            """users:
              builtins.mapAttrs
                (_: user:
                  builtins.concatLists (
                    builtins.attrValues (
                      builtins.mapAttrs
                        (location: value:
                          (builtins.map (d: {
                            location = location;
                            storage = d.persistentStoragePath;
                            old = location + d.dirPath;
                            new = d.persistentStoragePath + d.dirPath;
                            live = d.dirPath;
                          }) value.directories)
                          ++ (builtins.map (f: {
                            location = location;
                            storage = f.persistentStoragePath;
                            old = location + f.filePath;
                            new = f.persistentStoragePath + f.filePath;
                            live = f.filePath;
                          }) value.files))
                        (user.home.persistence or {}))))
                users""",
        ],
        capture_output=True,
        text=True,
    )
    if result.returncode:
        print(result.stderr, file=sys.stderr, end="")
        raise SystemExit(result.returncode)
    return json.loads(result.stdout)


def mkdirs(entry):
    """Create the app's storage parents, mirroring the flat layout's ownership.

    The activation script only fixes up directories it creates itself, so a
    parent left behind by `mkdir -p` as root would keep root:root 0755 — wrong
    for the persisted copy of a 0700 home directory.
    """
    storage = Path(entry["storage"])
    location = Path(entry["location"])
    for parent in reversed(Path(entry["new"]).parents):
        if not parent.is_relative_to(storage) or parent.exists():
            continue
        parent.mkdir()
        model = location / parent.relative_to(storage)
        if model.is_dir():
            stat = model.stat()
            os.chown(parent, stat.st_uid, stat.st_gid)
            parent.chmod(stat.st_mode & 0o7777)


def migrate(entry, apply):
    old = Path(entry["old"])
    new = Path(entry["new"])
    if old == new:
        return "unprefixed", f"{entry['live']}: storage layout unchanged"
    if not old.exists() and not old.is_symlink():
        if new.exists() or new.is_symlink():
            return "done", f"{entry['live']}: already at {new}"
        return "empty", f"{entry['live']}: no data to move"
    if new.exists() or new.is_symlink():
        return (
            "conflict",
            f"{entry['live']}: both {old} and {new} exist, moving nothing",
        )
    if apply:
        mkdirs(entry)
        shutil.move(str(old), str(new))
    return "moved", f"{entry['live']}: {old} -> {new}"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("host")
    parser.add_argument(
        "--apply", action="store_true", help="Actually move the data (default: dry run)"
    )
    args = parser.parse_args()

    # Creating the per-app storage roots needs write access to the location,
    # which is root-owned; the moves themselves happen inside the user's own
    # persisted home.
    if args.apply and os.geteuid() != 0:
        sudo = (
            "/run/wrappers/bin/sudo"
            if Path("/run/wrappers/bin/sudo").exists()
            else "sudo"
        )
        os.execvp(sudo, [sudo, sys.executable, *sys.argv])

    icons = {
        "moved": "📦",
        "done": "✅",
        "empty": "➖",
        "conflict": "⚠️ ",
        "unprefixed": "➖",
    }
    counts = {}
    for user, entries in evaluate(args.host).items():
        print(f"👤 {user}")
        for entry in sorted(entries, key=lambda e: e["live"]):
            status, message = migrate(entry, args.apply)
            counts[status] = counts.get(status, 0) + 1
            if status in {"empty", "unprefixed"}:
                continue
            print(f"  {icons[status]} {message}")

    print()
    print(", ".join(f"{count} {status}" for status, count in sorted(counts.items())))
    if not args.apply and counts.get("moved"):
        print("🔍 Dry run — pass `--apply` to move the data")
    if counts.get("conflict"):
        print("⚠️  Resolve the conflicts by hand: keep one copy, delete the other")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
