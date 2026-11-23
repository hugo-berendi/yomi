"""Exercise backup recovery with committed rows still in SQLite's WAL."""

import importlib.util
import os
import sqlite3
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "expose_backup",
    os.environ.get(
        "EXPOSE_BACKUP_HELPER",
        Path(__file__).parents[1] / "modules/nixos/expose/backup.py",
    ),
)
backup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(backup)


class BackupTest(unittest.TestCase):
    def test_live_wal_and_interrupted_publish(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            state = root / "live"
            (state / "config/db").mkdir(parents=True)
            (state / "config/logs").mkdir()
            (state / "config/traefik").mkdir()
            (state / "config/traefik/access.json").write_text("private-request")
            (state / "config/key").write_text("test-wireguard-key")
            (state / "config/logs/request.log").write_text("private-request")
            credentials = root / "credentials"
            credentials.write_text("SERVER_SECRET=test-only")
            destination = root / "snapshot"
            with sqlite3.connect(state / "config/db/db.sqlite") as database:
                database.execute("PRAGMA journal_mode=WAL")
                database.execute("CREATE TABLE users (name TEXT)")
                database.execute("INSERT INTO users VALUES ('owner')")
                database.commit()
                backup.snapshot(state, credentials, destination)
                with sqlite3.connect(destination / "config/db/db.sqlite") as restored:
                    self.assertEqual(
                        restored.execute("SELECT name FROM users").fetchall(),
                        [("owner",)],
                    )
                self.assertEqual(
                    (destination / "server.env").read_text(), "SERVER_SECRET=test-only"
                )
                self.assertFalse((destination / "config/logs").exists())
                self.assertFalse((destination / "config/traefik/access.json").exists())
                self.assertEqual(destination.stat().st_mode & 0o777, 0o700)
                destination.rename(root / "snapshot.previous")
                backup.snapshot(state, credentials, destination)
                self.assertEqual(
                    (destination / "config/key").read_text(), "test-wireguard-key"
                )
                credentials.unlink()
                with self.assertRaises(FileNotFoundError):
                    backup.snapshot(state, credentials, destination)
                self.assertTrue((destination / "config/db/db.sqlite").is_file())


if __name__ == "__main__":
    unittest.main()
