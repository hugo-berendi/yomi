import importlib.util
import json
import shlex
import tempfile
import unittest
from pathlib import Path
from unittest import mock


MODULE = Path(__file__).parents[1] / "hosts/nixos/inari/services/t3code-vm/bootstrap.py"
SPEC = importlib.util.spec_from_file_location("t3code_vm_bootstrap", MODULE)
bootstrap = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(bootstrap)


class BootstrapTests(unittest.TestCase):
    def test_ssh_arguments_keep_values_out_of_shell_and_use_pinning(self):
        command = ["sudo", "echo", "value; $(touch /tmp/unwanted)"]
        args = bootstrap.ssh_args(Path("/key"), Path("/known"), command)
        self.assertIn("StrictHostKeyChecking=yes", args)
        self.assertEqual(shlex.split(args[-1]), command)
        self.assertEqual(args[-3:-1], ["--", "agent@10.231.0.2"])

    def test_credentials_are_allowlisted_and_missing_files_are_skipped(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "auth.json"
            source.write_text("secret")
            pairs = bootstrap.credential_pairs(
                [str(source), str(source) + ".missing"], "/home/agent"
            )
            self.assertEqual(pairs, [(source, Path("/home/agent") / "auth.json")])

    def test_state_write_is_atomic_and_link_revocation_is_sticky(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "state.json"
            bootstrap.atomic_json(path, {"linked": True, "environmentId": "guest"})
            self.assertEqual(json.loads(path.read_text())["environmentId"], "guest")
        self.assertEqual(
            bootstrap.state_for_link({"linked": True, "environmentId": "guest"}, []),
            {"linked": False, "environmentId": "guest", "revoked": True},
        )

    def test_install_file_does_not_put_credentials_in_argv(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "auth.json"
            source.write_text("secret")
            with mock.patch.object(bootstrap.subprocess, "run") as run:
                bootstrap.install_file(
                    Path("/key"), Path("/known"), source, Path("/remote/auth.json")
                )
            self.assertNotIn("secret", " ".join(run.call_args.args[0]))
            self.assertTrue(run.call_args.kwargs["check"])


if __name__ == "__main__":
    unittest.main()
