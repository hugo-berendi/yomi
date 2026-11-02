import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).parents[1]
INSTALLER = ROOT / "home/features/cli/ai/install-skill-instructions.py"


class AgentPolicyTests(unittest.TestCase):
    def test_repeat_install_preserves_preferences_and_permissions(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            policy = home / "policy"
            policy.write_text("use linux-test-environment\n")
            targets = [
                ".codex/AGENTS.md",
                ".claude/CLAUDE.md",
                ".copilot/copilot-instructions.md",
            ]
            for relative in targets:
                target = home / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text("Hugo's existing preferences\n")
                target.chmod(0o600)
            for _ in range(2):
                subprocess.run(
                    [sys.executable, str(INSTALLER), str(home), str(policy)], check=True
                )
            for relative in targets:
                target = home / relative
                self.assertIn("Hugo's existing preferences", target.read_text())
                self.assertEqual(
                    target.read_text().count("BEGIN MANAGED SKILL USAGE"), 1
                )
                self.assertEqual(os.stat(target).st_mode & 0o777, 0o600)


if __name__ == "__main__":
    unittest.main()
