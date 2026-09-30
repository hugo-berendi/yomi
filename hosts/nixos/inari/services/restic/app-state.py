"""Stage selected directories from frozen ZFS snapshots for encrypted backup."""

import json
from contextlib import closing
import os
from pathlib import Path
import shutil
import sqlite3
import stat
import subprocess
import sys


def stage_state(manifest, destination):
    destination = Path(destination)
    staging = destination.with_name(destination.name + ".partial")
    previous = destination.with_name(destination.name + ".previous")
    # A crash between the two renames must not discard the last complete copy.
    if previous.exists() and not destination.exists():
        previous.rename(destination)
    shutil.rmtree(staging, ignore_errors=True)
    staging.mkdir(mode=0o700)
    databases = {}
    for name, app in manifest.items():
        source = Path(app["source"])
        if not source.is_dir():
            raise RuntimeError(f"Missing snapshot source for {name}")
        target = staging / name
        target.mkdir(mode=0o700)
        for entry in source.iterdir():
            if entry.name not in app.get("exclude", []):
                subprocess.run(
                    ["cp", "-a", "--reflink=auto", "--", str(entry), str(target)],
                    check=True,
                )
        # cp preserves nested ownership; copy the application's root metadata too.
        metadata = source.stat()
        os.chown(target, metadata.st_uid, metadata.st_gid)
        target.chmod(stat.S_IMODE(metadata.st_mode))
        databases[name] = []
        for root, _, files in os.walk(target, followlinks=False):
            for filename in files:
                database = Path(root) / filename
                if database.is_symlink() or not database.is_file():
                    continue
                with database.open("rb") as file:
                    is_sqlite = file.read(16) == b"SQLite format 3\x00"
                if not is_sqlite:
                    continue
                # Recover committed WAL state or roll back a hot journal, then
                # produce a standalone file. Recovery may write the staged
                # copy; it must never run against the live database.
                clean = database.with_name(database.name + ".backup-tmp")
                metadata = database.stat()
                with closing(
                    sqlite3.connect(database.as_uri() + "?mode=rw", uri=True)
                ) as src:
                    with closing(sqlite3.connect(clean)) as dst:
                        src.backup(dst)
                        result = dst.execute("PRAGMA integrity_check").fetchall()
                        if result != [("ok",)]:
                            raise RuntimeError(
                                f"SQLite integrity check failed for {name}"
                            )
                clean.chmod(stat.S_IMODE(metadata.st_mode))
                os.chown(clean, metadata.st_uid, metadata.st_gid)
                clean.replace(database)
                for suffix in ("-wal", "-shm", "-journal"):
                    Path(str(database) + suffix).unlink(missing_ok=True)
                databases[name].append(str(database.relative_to(target)))
        if not set(app.get("sqlite", [])).issubset(databases[name]):
            raise RuntimeError(
                f"Required SQLite database missing or invalid for {name}"
            )
    (staging / "manifest.json").write_text(
        json.dumps({"applications": manifest, "sqliteDatabases": databases}, indent=2)
        + "\n"
    )
    shutil.rmtree(previous, ignore_errors=True)
    if destination.exists():
        destination.rename(previous)
    staging.rename(destination)
    shutil.rmtree(previous, ignore_errors=True)


if __name__ == "__main__":
    stage_state(json.loads(Path(sys.argv[1]).read_text()), sys.argv[2])
