"""Verify WAL recovery, ownership, retries and failed staging without live data."""

from contextlib import closing
import json
import os
from pathlib import Path
import sqlite3
import subprocess
import sys

helper, unit, production_manifest = sys.argv[1:]
root = Path(os.environ["TMPDIR"]) / "app-state-test"
source = root / "snapshot"
source.mkdir(parents=True, mode=0o700)
destination = root / "published"
database = source / "db.sqlite3"
manifest = root / "sources.json"
manifest.write_text(
    json.dumps(
        {
            "paperless": {
                "source": str(source),
                "sqlite": ["db.sqlite3"],
                "exclude": ["dump"],
            }
        }
    )
)


def run(success=True):
    result = subprocess.run(
        [sys.executable, helper, str(manifest), str(destination)],
        capture_output=True,
        text=True,
    )
    if success:
        if result.returncode:
            print(result.stderr)
        result.check_returncode()
    else:
        assert result.returncode != 0, "Invalid staging must fail"


def count():
    with closing(sqlite3.connect(destination / "paperless/db.sqlite3")) as db:
        assert db.execute("PRAGMA integrity_check").fetchall() == [("ok",)]
        return db.execute("SELECT count(*) FROM documents_document").fetchone()[0]


with (
    closing(sqlite3.connect(database)) as writer,
    closing(sqlite3.connect(source / "rollback.sqlite3")) as rollback,
):
    rollback.execute("PRAGMA journal_mode=DELETE")
    rollback.execute("PRAGMA cache_size=5")
    rollback.execute("CREATE TABLE recovery (id INTEGER PRIMARY KEY, payload BLOB)")
    rollback.execute("INSERT INTO recovery VALUES (1, zeroblob(8192))")
    rollback.commit()
    rollback.execute("BEGIN IMMEDIATE")
    rollback.execute("INSERT INTO recovery VALUES (2, zeroblob(1048576))")
    assert (source / "rollback.sqlite3-journal").exists()
    writer.execute("PRAGMA journal_mode=WAL")
    writer.execute("PRAGMA wal_autocheckpoint=0")
    writer.execute("CREATE TABLE documents_document (id INTEGER PRIMARY KEY)")
    writer.execute("INSERT INTO documents_document VALUES (1)")
    writer.commit()
    database.chmod(0o640)
    # This row exists only in the WAL until the writer closes. A plain copy of
    # db.sqlite3 would lose both the schema and the committed row.
    assert Path(str(database) + "-wal").stat().st_size > 0
    (source / "config").write_text("synthetic-encryption-key")
    (source / "config").chmod(0o600)
    (source / "managed-link").symlink_to(root / "outside")
    (source / "dump").mkdir()
    (source / "dump/old-archive").write_text("redundant dump")
    writer.execute("INSERT INTO documents_document VALUES (99)")
    run()
    assert count() == 1, "Uncommitted data must not enter a SQLite backup"
    with closing(sqlite3.connect(destination / "paperless/rollback.sqlite3")) as db:
        assert db.execute("SELECT count(*) FROM recovery").fetchone()[0] == 1
    rollback.rollback()
    writer.rollback()
    assert not (destination / "paperless/db.sqlite3-wal").exists()
    assert not (destination / "paperless/db.sqlite3-shm").exists()
    assert not (destination / "paperless/dump").exists()
    assert (destination / "paperless/managed-link").is_symlink()
    assert (destination / "paperless/config").read_text() == "synthetic-encryption-key"
    assert (destination / "paperless/config").stat().st_mode & 0o777 == 0o600
    assert (destination / "paperless/db.sqlite3").stat().st_mode & 0o777 == 0o640
    assert destination.stat().st_mode & 0o777 == 0o700
    assert (destination / "paperless").stat().st_uid == source.stat().st_uid
    assert (destination / "paperless").stat().st_gid == source.stat().st_gid
    run()
    assert count() == 1
    writer.execute("INSERT INTO documents_document VALUES (2)")
    writer.commit()
    run()
    assert count() == 2, "A repeated run must publish the new committed state"

# A source failure must leave the previous complete backup usable. Reproduce
# the interrupted publication window and stale partial data before retrying.
destination.rename(destination.with_name("published.previous"))
partial = destination.with_name("published.partial")
partial.mkdir()
(partial / "incomplete").write_text("discard me")
manifest.write_text(json.dumps({"paperless": {"source": str(root / "missing")}}))
run(success=False)
assert count() == 2
manifest.write_text(
    json.dumps({"paperless": {"source": str(source), "sqlite": ["missing.sqlite"]}})
)
run(success=False)
assert count() == 2
manifest.write_text(
    json.dumps({"paperless": {"source": str(source), "sqlite": ["db.sqlite3"]}})
)
run()
assert count() == 2
assert not partial.exists()
assert not destination.with_name("published.previous").exists()
print("Application state staging regression passed")

# Exercise the actual generated service script and its source selection. Only
# the privileged ZFS commands are replaced; no production path is read.
configured = json.loads(Path(production_manifest).read_text())
assert set(configured) >= {
    "vaultwarden",
    "forgejo",
    "n8n",
    "home-assistant",
    "pocket-id",
    "matrix",
    "mautrix-discord",
    "mautrix-signal",
    "mautrix-whatsapp",
    "karakeep",
    "calendar-sync",
    "ntfy",
    "paperless",
    "ssh",
}
sources = {}
for name, app in configured.items():
    assert app["source"].startswith("/run/restic-app-state/")
    folder = root / "unit-snapshots" / name
    folder.mkdir(parents=True, mode=0o700)
    (folder / "state").write_text("synthetic state")
    sources[name] = app | {"source": str(folder)}
    for filename in app.get("sqlite", []):
        path = folder / filename
        path.parent.mkdir(parents=True, exist_ok=True)
        with closing(sqlite3.connect(path)) as db:
            db.execute("CREATE TABLE fixture (id INTEGER PRIMARY KEY)")
            db.execute("INSERT INTO fixture VALUES (37)")
            db.commit()
    if name == "n8n":
        (folder / ".n8n/config").write_text("synthetic-encryption-key")
manifest.write_text(json.dumps(sources))
tools = root / "tools"
tools.mkdir()
markers = root / "held-snapshots"
markers.mkdir()
mounts = root / "held-mounts"
mounts.mkdir()
fake_zfs = tools / "zfs"
fake_zfs.write_text(
    f"#!{sys.executable}\n"
    + """
import os
from pathlib import Path
import sys
markers = Path(os.environ['YOMI_TEST_SNAPSHOTS'])
command, snapshot = sys.argv[1], sys.argv[-1]
marker = markers / (snapshot.replace('/', '-') + '.held')
if command == 'list':
    sys.exit(0 if marker.exists() else 1)
if command == 'snapshot':
    if os.environ.get('YOMI_TEST_FAIL_SNAPSHOT') and list(markers.iterdir()):
        sys.exit(19)
    assert not marker.exists(), 'Stale snapshot was not cleaned'
    marker.touch()
elif command == 'destroy':
    assert not any(p.read_text() == snapshot for p in Path(os.environ['YOMI_TEST_MOUNTS']).iterdir()), 'Snapshot destroyed while mounted'
    marker.unlink()
else:
    raise AssertionError('Unexpected ZFS command')
"""
)
fake_zfs.chmod(0o755)
fake_mount = tools / "mount"
fake_mount.write_text(
    f"#!{sys.executable}\n"
    + """
import os
from pathlib import Path
import sys
command = Path(sys.argv[0]).name
mounts = Path(os.environ['YOMI_TEST_MOUNTS'])
marker = mounts / Path(sys.argv[-1]).name
if command == 'mountpoint':
    sys.exit(0 if marker.exists() else 1)
if command == 'umount':
    marker.unlink()
else:
    assert sys.argv[1:5] == ['-t', 'zfs', '-o', 'ro']
    snapshot = sys.argv[-2]
    held = Path(os.environ['YOMI_TEST_SNAPSHOTS']) / (snapshot.replace('/', '-') + '.held')
    assert held.exists(), 'Mounted before taking a snapshot'
    if os.environ.get('YOMI_TEST_FAIL_MOUNT') and list(mounts.iterdir()):
        sys.exit(20)
    marker.write_text(snapshot)
"""
)
fake_mount.chmod(0o755)
for name in ("umount", "mountpoint"):
    (tools / name).symlink_to(fake_mount)
env = os.environ | {
    "PATH": str(tools) + os.pathsep + os.environ["PATH"],
    "APP_STATE_SOURCES": str(manifest),
    "APP_STATE_DESTINATION": str(destination),
    "YOMI_TEST_SNAPSHOTS": str(markers),
    "YOMI_TEST_MOUNTS": str(mounts),
    "RUNTIME_DIRECTORY": str(root / "runtime"),
}
for _ in range(2):
    subprocess.run([unit], env=env, check=True)
    assert not list(markers.iterdir()), "Successful staging left snapshots held"
    assert not list(mounts.iterdir()), "Successful staging left snapshots mounted"
    for name, app in configured.items():
        assert (destination / name / "state").read_text() == "synthetic state"
        for filename in app.get("sqlite", []):
            with closing(sqlite3.connect(destination / name / filename)) as db:
                assert db.execute("SELECT id FROM fixture").fetchone() == (37,)
assert (destination / "n8n/.n8n/config").read_text() == "synthetic-encryption-key"

failed = subprocess.run(
    [unit], env=env | {"YOMI_TEST_FAIL_SNAPSHOT": "1"}, capture_output=True
)
assert failed.returncode != 0
assert not list(markers.iterdir()), "A partial snapshot failure leaked a snapshot"
assert not list(mounts.iterdir()), "A partial snapshot failure leaked a mount"
failed = subprocess.run(
    [unit], env=env | {"YOMI_TEST_FAIL_MOUNT": "1"}, capture_output=True
)
assert failed.returncode != 0
assert not list(markers.iterdir()), "A partial mount failure leaked a snapshot"
assert not list(mounts.iterdir()), "A partial mount failure leaked a mount"
required_db = Path(sources["paperless"]["source"]) / "db.sqlite3"
required_db.rename(required_db.with_name("missing.sqlite"))
failed = subprocess.run([unit], env=env, capture_output=True)
assert failed.returncode != 0
assert not list(markers.iterdir()), "A staging failure leaked snapshots"
assert not list(mounts.iterdir()), "A staging failure leaked snapshot mounts"
assert (destination / "paperless/db.sqlite3").exists(), (
    "Failed staging replaced the last backup"
)
print("Generated app-state service lifecycle and coverage regression passed")
