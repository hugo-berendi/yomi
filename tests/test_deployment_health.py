"""Post-activation checks must reject application failures and allow warm-up."""

import importlib.util
import io
import unittest
from pathlib import Path
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location(
    "deployment_health", Path(__file__).parents[1] / "scripts/ops/deployment-health.py"
)
health = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(health)


class DeploymentHealthTests(unittest.TestCase):
    def test_http_success_with_failed_database_is_unhealthy(self):
        with patch.object(
            health, "urlopen", return_value=io.BytesIO(b'{"database":"error"}')
        ):
            with self.assertRaises(RuntimeError):
                health.probe(
                    {
                        "url": "http://127.0.0.1:3000/api/health",
                        "json": {"database": "ok"},
                    }
                )

    def test_required_command_failure_is_unhealthy(self):
        with patch.object(
            health.subprocess,
            "run",
            side_effect=health.subprocess.CalledProcessError(1, ["check"]),
        ):
            with self.assertRaises(health.subprocess.CalledProcessError):
                health.probe({"command": ["check"]})

    def test_warming_service_can_recover(self):
        with (
            patch.object(health, "probe", side_effect=[OSError(), None]),
            patch.object(health.time, "sleep"),
            patch.object(health.time, "monotonic", side_effect=[0, 1, 2]),
        ):
            self.assertTrue(health.wait_healthy([{"name": "application"}], 5, 1))

    def test_failure_after_deadline_rejects_deployment(self):
        with (
            patch.object(health, "probe", side_effect=OSError()),
            patch.object(health.time, "monotonic", side_effect=[0, 6]),
        ):
            self.assertFalse(health.wait_healthy([{"name": "application"}], 5, 1))


if __name__ == "__main__":
    unittest.main()
