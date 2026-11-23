"""Stage selected directories from frozen ZFS snapshots for encrypted backup."""

import json
import os
import shutil
import sqlite3
import stat
import subprocess
import sys
from contextlib import closing
from pathlib import Path


def stage_state(manifest, destination):
    destination = Path(destination)
    staging = destination.with_name(destination.name + ".partial")
    previous = destination.with_name(destination.name + ".previous")
    # A crash between the two renames must not discard the last complete copy.
    if previous.exists() and not destination.exists():
        previous.rename(destination)
    shutil.rmtree(staging, ignore_errors=True)
    staging.mkdir(mode=0o700)
    # A failed run must not leave a full copy of application state, secrets
    # included, sitting next to the published one until the next run.
    try:
        databases = {}
        for name, app in manifest.items():
            source = Path(app["source"])
            if not source.is_dir():
                raise RuntimeError(f"Missing snapshot source for {name}")
            target = staging / name
            target.mkdir(mode=0o700)
            excluded = app.get("exclude", [])
            for entry in source.iterdir():
                if entry.name not in excluded:
                    subprocess.run(
                        ["cp", "-a", "--reflink=auto", "--", str(entry), str(target)],
                        check=True,
                    )
            # Nested exclusions are removed from the private staging copy. The
            # manifest is static Nix configuration, never data from the snapshot.
            for relative in excluded:
                if "/" not in relative:
                    continue
                relative_path = Path(relative)
                if relative_path.is_absolute() or ".." in relative_path.parts:
                    raise RuntimeError(
                        f"Invalid nested exclusion for {name}: {relative}"
                    )
                if any(
                    (target / parent).is_symlink() for parent in relative_path.parents
                ):
                    raise RuntimeError(
                        f"Symlink parent in exclusion for {name}: {relative}"
                    )
                path = target / relative_path
                if path.is_dir() and not path.is_symlink():
                    shutil.rmtree(path)
                else:
                    path.unlink(missing_ok=True)
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
                    with (
                        closing(
                            sqlite3.connect(database.as_uri() + "?mode=rw", uri=True)
                        ) as src,
                        closing(sqlite3.connect(clean)) as dst,
                    ):
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
            # H2's MVStore appends checksummed chunks and reopens at the last
            # complete one, so a copy from the frozen snapshot is crash-consistent.
            # Opening it needs a JVM; the monthly restore rehearsal does that on
            # a restored copy, so each backup run only checks the file header.
            for relative in app.get("h2", []):
                database = target / relative
                if database.is_symlink() or not database.is_file():
                    raise RuntimeError(f"Required H2 database missing for {name}")
                with database.open("rb") as file:
                    if file.read(4) != b"H:2,":
                        raise RuntimeError(f"Required H2 database invalid for {name}")
        (staging / "manifest.json").write_text(
            json.dumps(
                {"applications": manifest, "sqliteDatabases": databases}, indent=2
            )
            + "\n"
        )
    except BaseException:
        shutil.rmtree(staging, ignore_errors=True)
        raise
    shutil.rmtree(previous, ignore_errors=True)
    if destination.exists():
        destination.rename(previous)
    staging.rename(destination)
    shutil.rmtree(previous, ignore_errors=True)


if __name__ == "__main__":
    stage_state(json.loads(Path(sys.argv[1]).read_text()), sys.argv[2])
