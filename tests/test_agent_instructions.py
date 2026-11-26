"""The agent instruction installer keeps the pilot's own text and converges."""

import importlib.util
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

INSTALLER = Path(
    os.environ.get(
        "AGENT_INSTRUCTIONS_INSTALLER",
        Path(__file__).parents[1] / "home/features/cli/ai/install-instructions.py",
    )
)
spec = importlib.util.spec_from_file_location("installer", INSTALLER)
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)

LEGACY = ["INARI EFFICIENT DELEGATION", "MANAGED SKILL USAGE"]


def block(name, text):
    return {"name": name, "text": text}


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.path = self.home / ".claude/CLAUDE.md"

    def install(self, blocks, legacy=LEGACY):
        manifest = {"files": {".claude/CLAUDE.md": blocks}, "legacy": legacy}
        installer.main(self.home, manifest)
        return self.path.read_text() if self.path.exists() else None

    def test_repeat_install_keeps_user_text_and_mode(self):
        self.path.parent.mkdir()
        self.path.write_text("My own rules\n")
        self.path.chmod(0o600)
        first = self.install([block("a", "one"), block("b", "two")])
        self.assertEqual(self.install([block("a", "one"), block("b", "two")]), first)
        self.assertTrue(first.startswith("My own rules\n"))
        self.assertEqual(first.count("<!-- BEGIN YOMI a -->"), 1)
        self.assertEqual(self.path.stat().st_mode & 0o777, 0o600)

    def test_replaces_legacy_blocks_in_place(self):
        self.path.parent.mkdir()
        self.path.write_text(
            "<!-- BEGIN INARI EFFICIENT DELEGATION -->\nold routing\n"
            "<!-- END INARI EFFICIENT DELEGATION -->\n\n"
            "<!-- BEGIN MANAGED SKILL USAGE -->\nold usage\n"
            "<!-- END MANAGED SKILL USAGE -->\n\n"
            "<!-- BEGIN MANAGED SKILL AUTHORING -->\nkept\n"
            "<!-- END MANAGED SKILL AUTHORING -->\n\nUser rules\n"
        )
        text = self.install([block("a", "new")])
        self.assertNotIn("old", text)
        self.assertTrue(text.startswith("<!-- BEGIN YOMI a -->\nnew\n"))
        self.assertIn("MANAGED SKILL AUTHORING -->\nkept", text)
        self.assertTrue(text.endswith("User rules\n"))

    def test_other_writers_block_survives_when_not_legacy(self):
        self.path.parent.mkdir()
        usage = "<!-- BEGIN MANAGED SKILL USAGE -->\nskills flake\n<!-- END MANAGED SKILL USAGE -->\n"
        self.path.write_text(usage)
        self.assertIn(usage, self.install([block("a", "x")], legacy=[]))

    def test_dropped_block_disappears(self):
        self.install([block("a", "one"), block("b", "two")])
        text = self.install([block("b", "two")])
        self.assertNotIn("YOMI a", text)
        self.install([])
        self.assertEqual(self.path.read_text(), "")

    def test_no_file_is_created_without_blocks(self):
        self.install([])
        self.assertFalse(self.path.exists())

    def test_unmatched_marker_is_refused_without_writing(self):
        self.path.parent.mkdir()
        broken = "<!-- BEGIN YOMI a -->\nunfinished\n"
        self.path.write_text(broken)
        with self.assertRaises(SystemExit):
            self.install([block("a", "x")])
        self.assertEqual(self.path.read_text(), broken)

    def test_command_line(self):
        manifest = self.home / "manifest.json"
        manifest.write_text(
            json.dumps({"files": {".codex/AGENTS.md": [block("a", "x")]}})
        )
        self.assertEqual(
            os.system(f"{sys.executable} {INSTALLER} {self.home} {manifest}"), 0
        )
        self.assertIn("YOMI a", (self.home / ".codex/AGENTS.md").read_text())


if __name__ == "__main__":
    unittest.main()
