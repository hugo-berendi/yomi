import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import MagicMock, patch

PATH = Path(__file__).parents[1] / "scripts/ci/request-package-repair.py"
SPEC = importlib.util.spec_from_file_location("repair_request", PATH)
request = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(request)


class RepairRequestTests(unittest.TestCase):
    def invoke(self, failures, environment, response='{"threadId":"repair"}'):
        with tempfile.TemporaryDirectory() as directory:
            report = Path(directory) / "failures"
            report.write_text(failures)
            client = MagicMock()
            client.__enter__.return_value = client
            client.makefile.return_value.__enter__.return_value = io.StringIO(response)
            with (
                patch.object(request.sys, "argv", [str(PATH), str(report)]),
                patch.dict(
                    request.os.environ,
                    {"GITHUB_RUN_ID": "321", **environment},
                    clear=True,
                ),
                patch.object(request.socket, "socket", return_value=client) as factory,
                patch("sys.stdout", new_callable=io.StringIO),
            ):
                request.main()
            return client, factory

    def test_successful_update_does_not_contact_t3(self):
        _, factory = self.invoke("", {"CI_OUTCOME": "success", "JOB_STATUS": "success"})
        factory.assert_not_called()

    def test_reverted_t3_update_launches_repair_even_without_ci_changes(self):
        client, _ = self.invoke(
            "t3code update or patch rebase failed", {"CI_OUTCOME": "skipped"}
        )
        payload = json.loads(client.sendall.call_args.args[0])
        self.assertEqual(payload["run_id"], "321")
        self.assertIn("patch rebase failed", payload["reason"])

    def test_ci_failure_launches_repair_without_a_package_error(self):
        client, _ = self.invoke("", {"CI_OUTCOME": "failure", "JOB_STATUS": "success"})
        self.assertIn(
            "Lint or flake checks failed",
            json.loads(client.sendall.call_args.args[0])["reason"],
        )

    def test_launcher_error_is_reported_as_failure(self):
        with self.assertRaisesRegex(RuntimeError, "offline"):
            self.invoke("update failed", {}, '{"error":"offline"}')
