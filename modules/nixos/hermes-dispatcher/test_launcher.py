import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


class LauncherTests(unittest.TestCase):
    def test_bootstrap_does_not_forward_api_credentials(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            configuration = root / "config.json"
            configuration.write_text("{}")
            instructions = root / "instructions"
            instructions.write_text("Test instructions")
            fake = root / "fake-signal"
            fake.write_text(
                f"#!{sys.executable}\nimport json, os\n"
                "print(json.dumps(dict(os.environ)))\n"
            )
            fake.chmod(0o700)
            state = root / "state"
            state.mkdir()
            (state / "signal-account").write_text("+491234567890\n")
            settings = root / "settings.json"
            settings.write_text(
                json.dumps(
                    {
                        "stateDirectory": str(state),
                        "configuration": str(configuration),
                        "instructions": str(instructions),
                        "socket": str(root / "signal.sock"),
                        "path": str(root),
                        "signal": str(fake),
                        "codex": str(fake),
                        "hermes": str(fake),
                    }
                )
            )
            command = [
                sys.executable,
                str(Path(__file__).with_name("launcher.py")),
                str(settings),
            ]
            result = subprocess.run(
                [*command, "signal"],
                check=True,
                capture_output=True,
                text=True,
                env={
                    **os.environ,
                    "OPENAI_API_KEY": "not-a-real-key",
                    "ANTHROPIC_API_KEY": "not-a-real-key",
                },
            )
            forwarded = json.loads(result.stdout)
            self.assertNotIn("OPENAI_API_KEY", forwarded)
            self.assertNotIn("ANTHROPIC_API_KEY", forwarded)
            self.assertEqual(forwarded["HOME"], str(state / "home"))
            self.assertEqual(forwarded["CODEX_HOME"], str(state / "codex"))
            self.assertEqual(forwarded["SIGNAL_ALLOWED_USERS"], "+491234567890")
            (state / "codex/auth.json").write_text(
                '{"auth_mode":"apikey","OPENAI_API_KEY":"not-a-real-key"}'
            )
            rejected = subprocess.run(
                [*command, "gateway"], capture_output=True, text=True
            )
            self.assertNotEqual(rejected.returncode, 0)
            self.assertIn("Only a ChatGPT subscription login", rejected.stderr)
            (state / "hermes/.env").write_text("OPENAI_API_KEY=not-a-real-key\n")
            rejected = subprocess.run(
                [*command, "signal"], capture_output=True, text=True
            )
            self.assertNotEqual(rejected.returncode, 0)
            self.assertIn("only subscription login", rejected.stderr)


if __name__ == "__main__":
    unittest.main()
