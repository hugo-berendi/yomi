from pathlib import Path
import tempfile
import unittest
from local_tools import LocalTools


class LocalToolsTests(unittest.TestCase):
    def test_skill_reads_cannot_escape_the_selected_skill(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            skill = root / "skills/unslop"
            skill.mkdir(parents=True)
            (skill / "SKILL.md").write_text("Skill contents")
            (root / "outside").write_text("Private data")
            tool = LocalTools({"skills": str(root / "skills")})
            self.assertEqual(
                tool.handle("ciel_skill_read", {"skill": "unslop"}), "Skill contents"
            )
            with self.assertRaises(ValueError):
                tool.handle(
                    "ciel_skill_read", {"skill": "unslop", "path": "../../outside"}
                )

    def test_memory_preserves_revisions_and_rejects_credentials(self):
        with tempfile.TemporaryDirectory() as directory:
            tool = LocalTools({"memoryDirectory": directory})
            original = tool.handle("ciel_memory_read", {"kind": "preferences"})
            args = {
                "kind": "preferences",
                "etag": original["etag"],
                "entries": [
                    {
                        "fact": "Hugo prefers concise German replies",
                        "source": "Hugo",
                        "date": "2026-11-09",
                    }
                ],
            }
            tool.handle("ciel_memory_write", args)
            with self.assertRaises(ValueError):
                tool.handle("ciel_memory_write", args)
            new = tool.handle("ciel_memory_read", {"kind": "preferences"})
            self.assertEqual(new["entries"], args["entries"])
            args["etag"] = new["etag"]
            args["entries"][0]["fact"] = "access_token=do-not-store"
            with self.assertRaises(ValueError):
                tool.handle("ciel_memory_write", args)
            self.assertNotIn(
                "access_token", (Path(directory) / "preferences.json").read_text()
            )
