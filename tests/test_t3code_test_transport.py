import runpy
import unittest
from pathlib import Path
from unittest import mock

transport = runpy.run_path(
    str(Path(__file__).parents[1] / "scripts/ops/t3code-test.py")
)


class TransportTests(unittest.TestCase):
    def test_ssh_preserves_caller_failure_policy(self):
        with mock.patch("subprocess.run") as run:
            transport["ssh"](["true"], check=True)
            self.assertTrue(run.call_args.kwargs["check"])
            transport["ssh"](["false"])
            self.assertFalse(run.call_args.kwargs["check"])
