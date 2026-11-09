import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


class McpProtocolTests(unittest.TestCase):
    def test_stdio_initialization_and_skill_read_without_shell_or_broker(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "unslop").mkdir()
            (root / "unslop/SKILL.md").write_text("Cut formulaic phrasing.")
            (root / "catalog").write_text("unslop: writing")
            config = root / "config.json"
            config.write_text(
                json.dumps(
                    {
                        "skills": directory,
                        "catalog": str(root / "catalog"),
                        "memoryDirectory": str(root / "memory"),
                    }
                )
            )
            requests = [
                {
                    "id": 1,
                    "method": "initialize",
                    "params": {"protocolVersion": "2024-11-05"},
                },
                {"method": "notifications/initialized"},
                {"id": 2, "method": "tools/list"},
                {
                    "id": 3,
                    "method": "tools/call",
                    "params": {
                        "name": "ciel_skill_read",
                        "arguments": {"skill": "unslop"},
                    },
                },
                {
                    "id": 4,
                    "method": "tools/call",
                    "params": {
                        "name": "ciel_skill_read",
                        "arguments": {"skill": "unslop", "path": "../catalog"},
                    },
                },
            ]
            result = subprocess.run(
                [
                    sys.executable,
                    str(Path(__file__).with_name("mcp_server.py")),
                    str(config),
                ],
                input="".join(json.dumps(r) + "\n" for r in requests),
                text=True,
                capture_output=True,
                check=True,
            )
            replies = [json.loads(line) for line in result.stdout.splitlines()]
            self.assertEqual([r["id"] for r in replies], [1, 2, 3, 4])
            self.assertIn(
                "ciel_start_task", {t["name"] for t in replies[1]["result"]["tools"]}
            )
            self.assertEqual(
                replies[2]["result"]["content"][0]["text"], "Cut formulaic phrasing."
            )
            self.assertTrue(replies[3]["result"]["isError"])
            self.assertEqual(result.stderr, "")
