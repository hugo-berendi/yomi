"""Create a restorable Pangolin snapshot without copying a live SQLite file."""

import argparse
import os
import shutil
import sqlite3
from pathlib import Path


def snapshot(state: Path, credentials: Path, destination: Path) -> None:
    os.umask(0o077)
    source = state / "config"
    database = source / "db/db.sqlite"
    if not database.is_file() or not credentials.is_file():
        raise FileNotFoundError("Pangolin database and server credentials must exist")
    if destination.resolve().is_relative_to(state.resolve()):
        raise ValueError("Backup destination must be outside the live state")
    partial = destination.with_name(destination.name + ".partial")
    previous = destination.with_name(destination.name + ".previous")
    if not destination.exists() and previous.exists():
        previous.rename(destination)
    for path in (partial, previous):
        if path.exists():
            shutil.rmtree(path)
    partial.mkdir(parents=True, mode=0o700)
    try:
        shutil.copytree(
            source,
            partial / "config",
            ignore=shutil.ignore_patterns("db", "logs", "access.json*"),
        )
        target = partial / "config/db/db.sqlite"
        target.parent.mkdir(mode=0o700)
        with (
            sqlite3.connect(database.as_uri() + "?mode=ro", uri=True) as src,
            sqlite3.connect(target) as dst,
        ):
            src.backup(dst)
            if dst.execute("PRAGMA integrity_check").fetchone() != ("ok",):
                raise RuntimeError("Pangolin backup integrity check failed")
        shutil.copyfile(credentials, partial / "server.env")
        if destination.exists():
            destination.rename(previous)
        partial.rename(destination)
        if previous.exists():
            shutil.rmtree(previous)
    finally:
        if partial.exists():
            shutil.rmtree(partial)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("state", type=Path)
    parser.add_argument("credentials", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    snapshot(args.state, args.credentials, args.destination)
