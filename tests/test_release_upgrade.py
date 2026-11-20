"""Signed releases: only fresh, host-bound, signed closures activate; holds stop all.

Signatures are real ssh-keygen signatures. nix-store, nix-env and the
generation's own switch and readiness programs are small executables, so the
consumer runs its real subprocess path without touching this machine's Nix.
"""

import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


release = load("release_upgrade", "scripts/ops/release-upgrade.py")
COMMIT = "0123456789abcdef0123456789abcdef01234567"
NAR = "sha256:" + "0" * 52


def executable(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(f"#!{shutil.which('sh')}\n" + text)
    path.chmod(0o755)


class Fixture:
    def __init__(self, directory):
        self.root = Path(directory)
        self.store = self.root / "nix/store"
        self.log = self.root / "calls.log"
        self.log.touch()
        self.current = self.root / "current-system"
        self.old = self.toplevel("26.05.old")
        self.current.symlink_to(self.old)
        self.sequence = 0
        self.key = self.root / "publisher"
        subprocess.run(
            ["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", self.key], check=True
        )
        signers = self.root / "allowed_signers"
        public = (self.root / "publisher.pub").read_text().strip()
        signers.write_text(f'yomi-release namespaces="yomi-release" {public}\n')
        bin_dir = self.root / "bin"
        executable(
            bin_dir / "nix-store",
            f'echo "nix-store $*" >> {self.log}\n'
            f'[ "$1" = --query ] && cat {self.root}/nar-hash\nexit 0\n',
        )
        executable(bin_dir / "nix-env", f'echo "nix-env $*" >> {self.log}\n')
        (self.root / "nar-hash").write_text(NAR + "\n")
        self.path = f"{bin_dir}:{os.environ['PATH']}"
        self.config = {
            "host": "inari",
            "manifestUrl": "https://releases.example/inari/release.json",
            "signatureUrl": "https://releases.example/inari/release.json.sig",
            "allowedSigners": str(signers),
            "substituter": None,
            "stateDir": str(self.root / "state"),
            "storeDir": str(self.store),
            "profile": str(self.root / "profile"),
            "currentSystem": str(self.current),
            "readiness": str(self.root / "fallback-readiness"),
        }
        self.documents = {}

    def toplevel(self, version):
        digest = hashlib.sha256(version.encode()).hexdigest()
        alphabet = release.NIX_BASE32
        name = "".join(alphabet[int(c, 16) % 32] for c in digest[:32])
        path = self.store / f"{name}-nixos-system-inari-{version}"
        # The switch moves current-system first, as the real activation does.
        executable(
            path / "bin/switch-to-configuration",
            f'echo "switch $1 {path.name}" >> {self.log}\n'
            f'[ "$1" = switch ] || exit 0\n'
            f"[ -e {self.root}/switch-fails ] && {{ ln -sfn {path} {self.current}; exit 1; }}\n"
            f"ln -sfn {path} {self.current}\n",
        )
        executable(
            path / "sw/bin/yomi-deployment-health",
            f'echo "readiness {path.name}" >> {self.log}\n'
            f"[ ! -e {self.root}/unready ]\n",
        )
        return path

    def publish(
        self, toplevel, sequence=None, key=None, namespace="yomi-release", **fields
    ):
        now = int(time.time())
        manifest = {
            "format": 1,
            "host": "inari",
            "commit": COMMIT,
            "toplevel": str(toplevel),
            "narHash": NAR,
            "sequence": sequence or self.sequence + 1,
            "issuedAt": now - 60,
            "expiresAt": now + 86400,
        } | fields
        self.sequence = max(self.sequence, manifest["sequence"])
        document = self.root / "release.json"
        document.write_bytes(json.dumps(manifest, sort_keys=True).encode())
        signature = self.root / "release.json.sig"
        signature.unlink(missing_ok=True)
        subprocess.run(
            [
                "ssh-keygen",
                "-q",
                "-Y",
                "sign",
                "-f",
                key or self.key,
                "-n",
                namespace,
                document,
            ],
            check=True,
            capture_output=True,
        )
        self.documents = {
            self.config["manifestUrl"]: document.read_bytes(),
            self.config["signatureUrl"]: signature.read_bytes(),
        }
        return manifest

    def fetch(self, url):
        return self.documents[url]

    def apply(self):
        with patch.dict(os.environ, {"PATH": self.path}):
            return release.apply(self.config, fetcher=self.fetch)

    def calls(self):
        return self.log.read_text().splitlines()

    def state(self):
        return json.loads((Path(self.config["stateDir"]) / "state.json").read_text())


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.f = Fixture(directory.name)
        self.new = self.f.toplevel("26.05.new")

    def test_signed_release_activates_and_becomes_ready(self):
        self.f.publish(self.new)
        self.assertEqual(self.f.apply(), 0)
        self.assertEqual(os.path.realpath(self.f.current), str(self.new))
        self.assertEqual(self.f.state()["status"], "ready")
        calls = self.f.calls()
        self.assertIn(f"switch dry-activate {self.new.name}", calls)
        self.assertIn(f"switch switch {self.new.name}", calls)
        self.assertLess(
            calls.index(f"switch dry-activate {self.new.name}"),
            calls.index(f"switch switch {self.new.name}"),
        )

    def test_same_ready_release_is_a_no_op(self):
        self.f.publish(self.new)
        self.f.apply()
        before = len(self.f.calls())
        self.assertEqual(self.f.apply(), 0)
        self.assertEqual(len(self.f.calls()), before)

    def test_unready_release_stays_active_and_retry_only_rechecks(self):
        self.f.publish(self.new)
        (self.f.root / "unready").touch()
        self.assertEqual(self.f.apply(), release.EXIT_UNREADY)
        self.assertEqual(os.path.realpath(self.f.current), str(self.new))
        self.assertEqual(self.f.state()["status"], "unready")
        (self.f.root / "unready").unlink()
        before = len(self.f.calls())
        self.assertEqual(self.f.apply(), 0)
        retry = self.f.calls()[before:]
        self.assertEqual(retry, [f"readiness {self.new.name}"])
        self.assertEqual(self.f.state()["status"], "ready")

    def test_interrupted_switch_is_activated_again(self):
        self.f.publish(self.new)
        (self.f.root / "switch-fails").touch()
        with self.assertRaises(release.Failed):
            self.f.apply()
        self.assertEqual(self.f.state()["status"], "activating")
        (self.f.root / "switch-fails").unlink()
        self.assertEqual(self.f.apply(), 0)
        self.assertEqual(self.f.calls().count(f"switch switch {self.new.name}"), 2)

    def test_hold_stops_before_fetching(self):
        release.place_hold(self.f.config["stateDir"], "test")
        self.f.documents = {}
        with self.assertRaises(release.Held):
            self.f.apply()
        self.assertEqual(self.f.calls(), [])

    def test_hold_needs_its_exact_id_to_clear(self):
        hold = release.place_hold(self.f.config["stateDir"], "test")
        self.assertEqual(release.place_hold(self.f.config["stateDir"], "x"), hold)
        with self.assertRaises(release.Held):
            release.release_hold(self.f.config["stateDir"], "wrong")
        release.release_hold(self.f.config["stateDir"], hold["id"])
        release.check_hold(self.f.config["stateDir"])

    def test_older_sequence_is_a_replay(self):
        self.f.publish(self.new, sequence=5)
        self.f.apply()
        self.f.publish(self.f.old, sequence=4)
        with self.assertRaisesRegex(release.Rejected, "older"):
            self.f.apply()

    def test_two_manifests_with_one_sequence_are_rejected(self):
        self.f.publish(self.new, sequence=5)
        self.f.apply()
        other = self.f.toplevel("26.05.other")
        self.f.publish(other, sequence=5)
        with self.assertRaisesRegex(release.Rejected, "Two different"):
            self.f.apply()

    def test_manual_switch_after_ready_release_is_held_not_reverted(self):
        self.f.publish(self.new)
        self.f.apply()
        os.unlink(self.f.current)
        self.f.current.symlink_to(self.f.old)
        with self.assertRaises(release.Held):
            self.f.apply()
        self.assertEqual(os.path.realpath(self.f.current), str(self.f.old))

    def test_untrusted_key_is_rejected(self):
        stranger = self.f.root / "stranger"
        subprocess.run(
            ["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", stranger], check=True
        )
        self.f.publish(self.new, key=stranger)
        with self.assertRaisesRegex(release.Rejected, "signature"):
            self.f.apply()

    def test_signature_from_another_namespace_is_rejected(self):
        self.f.publish(self.new, namespace="file")
        with self.assertRaisesRegex(release.Rejected, "signature"):
            self.f.apply()

    def test_closure_hash_must_match(self):
        self.f.publish(self.new)
        (self.f.root / "nar-hash").write_text("sha256:" + "1" * 52 + "\n")
        with self.assertRaisesRegex(release.Rejected, "Closure hash"):
            self.f.apply()
        self.assertFalse((Path(self.f.config["stateDir"]) / "state.json").exists())

    def test_manifest_fields_bind_host_time_and_shape(self):
        now = int(time.time())
        cases = {
            "for 'amaterasu'": {"host": "amaterasu"},
            "expired": {"expiresAt": now - 1},
            "validity": {"issuedAt": now - 30 * 86400},
            "future": {"issuedAt": now + 3600},
            "exactly": {"extra": True},
            "commit": {"commit": "main"},
            "positive": {"sequence": True},
        }
        for message, fields in cases.items():
            with self.subTest(message):
                self.f.publish(self.new, **fields)
                with self.assertRaisesRegex(release.Rejected, message):
                    self.f.apply()

    def test_toplevel_must_be_this_hosts_system(self):
        foreign = str(self.new).replace("-inari-", "-amaterasu-")
        self.f.publish(foreign)
        with self.assertRaisesRegex(release.Rejected, "toplevel"):
            self.f.apply()

    def test_cli_reports_hold_with_distinct_exit_code(self):
        config = self.f.root / "config.json"
        config.write_text(json.dumps(self.f.config))
        release.place_hold(self.f.config["stateDir"], "test")
        with patch("sys.stderr"):
            self.assertEqual(
                release.main(["--config", str(config), "check-hold"]), release.EXIT_HELD
            )


class RecoveryHoldTests(unittest.TestCase):
    def test_recovered_root_is_held_with_a_stable_id(self):
        recover = load("recover", "pkgs/yomi-recover/recover.py")
        with tempfile.TemporaryDirectory() as mountpoint, patch("builtins.print"):
            first = recover.hold_releases(mountpoint, "recovered")
            again = recover.hold_releases(mountpoint, "other")
            self.assertEqual(first, again)
            state_dir = Path(mountpoint) / "persist/state/var/lib/yomi-release"
            self.assertEqual(state_dir.stat().st_mode & 0o777, 0o700)
            with self.assertRaisesRegex(release.Held, first["id"]):
                release.check_hold(state_dir)


if __name__ == "__main__":
    unittest.main()
