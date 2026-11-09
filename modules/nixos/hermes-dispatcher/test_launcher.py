import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import launcher


class LauncherTests(unittest.TestCase):
    def test_managed_skills_refresh_without_replacing_local_skills(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            local = root / "local"
            local.mkdir()
            (local / "SKILL.md").write_text("Keep this skill")
            for revision in ("first", "second"):
                bundle = root / revision
                bundle.mkdir()
                (bundle / "SKILL.md").write_text(revision)
                launcher.managed_link(root / "yomi", bundle)
                self.assertEqual((root / "yomi/SKILL.md").read_text(), revision)
            self.assertEqual((local / "SKILL.md").read_text(), "Keep this skill")
            with self.assertRaises(FileExistsError):
                launcher.managed_link(local, root / "second")

    def test_bootstrap_does_not_forward_api_credentials(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            configuration = root / "config.json"
            configuration.write_text("{}")
            instructions = root / "instructions"
            instructions.write_text("Test instructions")
            skills = root / "skills"
            skills.mkdir()
            catalog = root / "catalog"
            catalog.write_text("Test skill catalog")
            fake = root / "fake-signal"
            fake.write_text(
                f"#!{sys.executable}\nimport json, os\n"
                "print(json.dumps(dict(os.environ)))\n"
            )
            fake.chmod(0o700)
            state = root / "state"
            state.mkdir()
            (state / "matrix-auth.json").write_text(
                json.dumps(
                    {
                        "user_id": "@hermes:matrix.example.org",
                        "access_token": "test-matrix-token",
                        "device_id": "test-device",
                    }
                )
            )
            (state / "codex").mkdir()
            (state / "codex/auth.json").write_text('{"auth_mode":"chatgpt"}')
            settings = root / "settings.json"
            settings.write_text(
                json.dumps(
                    {
                        "stateDirectory": str(state),
                        "configuration": str(configuration),
                        "instructions": str(instructions),
                        "skills": str(skills),
                        "catalog": str(catalog),
                        "matrix": {
                            "homeserver": "http://127.0.0.1:8432",
                            "userId": "@hermes:matrix.example.org",
                            "allowedUser": "@hugo:matrix.example.org",
                        },
                        "path": str(root),
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
                [*command, "gateway"],
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
            self.assertEqual(
                forwarded["MATRIX_ALLOWED_USERS"], "@hugo:matrix.example.org"
            )
            self.assertEqual(forwarded["MATRIX_ALLOW_ALL_USERS"], "false")
            self.assertEqual(forwarded["MATRIX_E2EE_MODE"], "required")
            self.assertNotIn("SIGNAL_ACCOUNT", forwarded)
            self.assertEqual((state / "codex/skills/yomi").resolve(), skills)
            self.assertIn(str(catalog), (state / "hermes/SOUL.md").read_text())
            self.assertEqual(
                (state / "codex/AGENTS.md").read_text(),
                (state / "hermes/SOUL.md").read_text(),
            )
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
                [*command, "gateway"], capture_output=True, text=True
            )
            self.assertNotEqual(rejected.returncode, 0)
            self.assertIn("only subscription login", rejected.stderr)


if __name__ == "__main__":
    unittest.main()
