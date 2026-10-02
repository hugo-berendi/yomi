"""Validate authenticated manifests and disk guards without privileged operations."""

import importlib.util
import io
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location("recover", sys.argv.pop(1))
recover = importlib.util.module_from_spec(spec)
spec.loader.exec_module(recover)


class RecoveryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.key = self.directory / "identity"
        subprocess.run(["age-keygen", "-o", self.key], check=True, capture_output=True)
        self.public = recover.recipient(self.key)
        self.content = bytes(range(256)) * 8192
        self.entry = recover.encrypt_stream(
            io.BytesIO(self.content), self.directory / "chunk.age", self.public
        )

    def test_real_encryption_round_trip_and_tamper_detection(self):
        decoded = io.BytesIO()
        recover.check_artifact(self.directory, self.entry, self.key, decoded)
        self.assertEqual(decoded.getvalue(), self.content)
        path = self.directory / self.entry["file"]
        encrypted = path.read_bytes()
        path.write_bytes(encrypted[:-1] + bytes([encrypted[-1] ^ 1]))
        with self.assertRaises(recover.RecoveryError):
            recover.check_artifact(self.directory, self.entry, self.key)

    def test_wrong_identity_is_rejected(self):
        other = self.directory / "other"
        subprocess.run(["age-keygen", "-o", other], check=True, capture_output=True)
        with self.assertRaises(recover.RecoveryError):
            recover.check_artifact(self.directory, self.entry, other)

    def test_incomplete_producer_is_not_success(self):
        with self.assertRaises(recover.RecoveryError):
            recover.encrypt_stream(
                io.BytesIO(b"short"), self.directory / "short.age", self.public, 10
            )
        self.assertFalse((self.directory / "short.age").exists())

    def test_manifest_requires_complete_contiguous_entire_disk(self):
        entry = {**self.entry, "offset": 0}
        value = {
            "format": 1,
            "complete": True,
            "source": {"size": len(self.content)},
            "image": [entry],
            "artifacts": {},
        }
        recover.seal(self.directory, value, self.public)
        self.assertEqual(recover.load_manifest(self.directory, self.key), value)
        for invalid in (
            {**value, "complete": False},
            {**value, "source": {"size": len(self.content) + 1}},
            {**value, "image": [{**entry, "offset": 1}]},
        ):
            recover.seal(self.directory, invalid, self.public)
            with self.assertRaises(recover.RecoveryError):
                recover.load_manifest(self.directory, self.key)

    def test_artifact_traversal_and_symlinks_are_rejected(self):
        for filename in ("../identity", "/etc/shadow", ".", ".."):
            with self.assertRaises(recover.RecoveryError):
                recover.artifact_path(self.directory, {"file": filename})
        (self.directory / "link").symlink_to(self.key)
        with self.assertRaises(recover.RecoveryError):
            recover.artifact_path(self.directory, {"file": "link"})

    def test_disk_guards_protect_mounts_pools_and_backup_destination(self):
        info = {
            "name": "/dev/fixture",
            "mountpoints": [],
            "children": [{"name": "/dev/fixture1", "mountpoints": []}],
        }
        with patch.object(recover, "pool_devices", return_value={"/dev/fixture1"}):
            with self.assertRaises(recover.RecoveryError):
                recover.idle_disk(info)
        with (
            patch.object(recover, "pool_devices", return_value=set()),
            patch.object(recover, "backing_devices", return_value={"/dev/fixture1"}),
        ):
            with self.assertRaises(recover.RecoveryError):
                recover.idle_disk(info, self.directory)
        mounted = {**info, "mountpoints": ["/"]}
        with self.assertRaises(recover.RecoveryError):
            recover.idle_disk(mounted)

    def test_wrong_confirmation_and_concurrent_operation_are_rejected(self):
        with self.assertRaises(recover.RecoveryError):
            recover.confirmation(
                {
                    "name": "/dev/test",
                    "model": "fixture",
                    "size": 1,
                    "serial": "correct",
                },
                "test",
                "wrong",
            )
        with recover.lock(self.directory):
            with self.assertRaises(recover.RecoveryError):
                with recover.lock(self.directory):
                    pass


if __name__ == "__main__":
    unittest.main()
