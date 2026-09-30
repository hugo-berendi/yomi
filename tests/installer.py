"""Exercise the recovery installer without disks, keys or privileged commands."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


INSTALLER = Path(sys.argv.pop(1)).read_text()
STUB = r"""
import json
import os
from pathlib import Path
import sys

tool = Path(sys.argv[0]).name
args = sys.argv[1:]
with Path(os.environ["COMMAND_LOG"]).open("a") as log:
    log.write(json.dumps([tool, *args]) + "\n")
operation = tool + (":" + args[0] if args else "")
if os.environ.get("FAIL_TOOL") in (tool, operation):
    sys.exit(int(os.environ["FAIL_STATUS"]))
if tool == "mountpoint":
    sys.exit(0 if os.environ.get("KEYS_ALREADY_OPEN") == "1" else 1)
if tool == "nixos-generate-config" and not os.environ.get("EMPTY_HARDWARE"):
    print("# generated fixture\n{}")
"""


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.work = tempfile.TemporaryDirectory()
        self.addCleanup(self.work.cleanup)
        self.root = Path(self.work.name)
        self.repo = self.root / "repo"
        scripts = self.repo / "scripts"
        scripts.mkdir(parents=True)
        self.hardware = self.repo / "hosts/nixos/fixture/hardware/generated.nix"
        self.hardware.parent.mkdir(parents=True)
        self.hardware.write_text("# previous hardware\n{}\n")
        partitions = self.repo / "hosts/nixos/fixture/filesystems/partitions.nix"
        partitions.parent.mkdir()
        partitions.write_text("{}\n")
        keys = self.root / "keys"
        (keys / "fixture").mkdir(parents=True)
        for name in ("id_ed25519", "id_ed25519.pub", "ssh_host_ed25519_key"):
            (keys / "fixture" / name).write_text("synthetic install key\n")
        self.target = self.root / "target"
        self.script = scripts / "live.sh"
        self.script.write_text(
            INSTALLER.replace("/mnt", str(self.target)).replace(
                "/kagutsuchi/secrets", str(keys)
            )
        )
        tools = self.root / "bin"
        tools.mkdir()
        stub = tools / "stub"
        stub.write_text(f"#!{sys.executable}\n{STUB}")
        stub.chmod(0o755)
        for tool in (
            "git",
            "nix",
            "nixos-generate-config",
            "nixos-install",
            "nixos-enter",
            "mountpoint",
            "zpool",
        ):
            (tools / tool).symlink_to(stub)
        (scripts / "kagutsuchi.sh").symlink_to(stub)
        self.log = self.root / "commands.jsonl"
        self.env = {
            **os.environ,
            "PATH": f"{tools}:{os.environ['PATH']}",
            "COMMAND_LOG": str(self.log),
        }

    def run_installer(self, *args, **env):
        result = subprocess.run(
            [shutil.which("bash"), str(self.script), *args],
            # The script must find the checkout even when invoked elsewhere.
            cwd=self.root,
            env={**self.env, **env},
            capture_output=True,
            text=True,
            timeout=10,
        )
        calls = (
            [json.loads(line) for line in self.log.read_text().splitlines()]
            if self.log.exists()
            else []
        )
        return result, calls

    def test_invalid_arguments_do_not_open_keys_or_run_disko(self):
        for args in (
            (),
            ("missing", "mount"),
            ("../fixture", "disko"),
            ("fixture", "invalid"),
            ("fixture", "mount", "invalid"),
            ("fixture", "mount", ""),
        ):
            with self.subTest(args=args):
                result, calls = self.run_installer(*args)
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertEqual(calls, [])

    def test_required_failures_stop_the_sequence(self):
        for tool, status, action, forbidden in (
            ("nix:flake", 13, "install", "kagutsuchi.sh"),
            ("kagutsuchi.sh:open", 17, "install", "nixos-generate-config"),
            ("nix:run", 19, "install", "nixos-generate-config"),
            ("nixos-generate-config", 23, "install", "nixos-install"),
            ("git:add", 29, "install", "nixos-install"),
            ("nixos-install", 31, "install", "nixos-enter"),
            ("nixos-enter", 37, "enter", "nixos-install"),
            ("kagutsuchi.sh:close", 41, "enter", "nixos-install"),
        ):
            with self.subTest(tool=tool):
                self.log.unlink(missing_ok=True)
                previous = self.hardware.read_bytes()
                result, calls = self.run_installer(
                    "fixture",
                    "mount",
                    action,
                    FAIL_TOOL=tool,
                    FAIL_STATUS=str(status),
                )
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertNotIn("All done!", result.stdout)
                self.assertFalse(any(call[0] == forbidden for call in calls))
                if tool == "nixos-generate-config":
                    self.assertEqual(self.hardware.read_bytes(), previous)
                if tool != "nix:flake":
                    self.assertIn(["kagutsuchi.sh", "close"], calls)

    def test_success_stages_only_hardware_and_closes_owned_keys(self):
        for _ in range(2):
            self.log.unlink(missing_ok=True)
            result, calls = self.run_installer("fixture", "mount", "install")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("All done!", result.stdout)
            self.assertEqual(
                [call for call in calls if call[0] == "git"],
                [["git", "add", "--", "hosts/nixos/fixture/hardware/generated.nix"]],
            )
            self.assertIn(["kagutsuchi.sh", "close"], calls)
            self.assertEqual(self.hardware.read_text(), "# generated fixture\n{}\n")
            self.assertTrue(
                (self.target / "persist/state/etc/ssh/ssh_host_ed25519_key").is_file()
            )

    def test_preexisting_key_mount_is_left_open(self):
        result, calls = self.run_installer(
            "fixture", "mount", "enter", KEYS_ALREADY_OPEN="1"
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn(["kagutsuchi.sh", "close"], calls)

    def test_empty_hardware_output_keeps_previous_file(self):
        previous = self.hardware.read_bytes()
        result, calls = self.run_installer(
            "fixture", "mount", "install", EMPTY_HARDWARE="1"
        )
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertEqual(self.hardware.read_bytes(), previous)
        self.assertFalse(any(call[0] == "git" for call in calls))
        self.assertIn(["kagutsuchi.sh", "close"], calls)


if __name__ == "__main__":
    unittest.main()
