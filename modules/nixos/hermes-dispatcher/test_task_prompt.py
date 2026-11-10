"""Which rules and preferences reach a worker prompt, and the inari signing rule."""

import json
import tempfile
import unittest
from pathlib import Path

import task_blockers
from project_memory import project_facts
from task_policy import READONLY, task_prompt
from test_support import FakeT3, Workspace, make_dispatcher, start

SIGNING = "Commit nicht möglich: gpg: skipped key: No secret key. Signing failed."


def facts(entries, description):
    with tempfile.TemporaryDirectory() as root:
        (Path(root) / "projects.json").write_text(json.dumps(entries))
        return project_facts({"memoryDirectory": root}, description)


def entry(fact, **extra):
    return {"fact": fact, "source": "Hugo", "date": "2026-11-09", **extra}


class SigningTests(unittest.TestCase):
    def test_inari_allows_unsigned_and_never_contradicts_itself(self):
        prompt = task_prompt("Fix the cache", "style", allow_unsigned=True)
        self.assertIn("commit unsigned", prompt)
        self.assertNotIn("do not commit\nunsigned", prompt)
        self.assertNotIn("handed to amaterasu", prompt)

    def test_other_hosts_keep_the_smartcard_rule(self):
        prompt = task_prompt("Fix the cache", "style")
        self.assertIn("do not commit\nunsigned", prompt)
        self.assertNotIn("commit unsigned,", prompt)

    def test_inari_does_not_park_a_signing_report(self):
        self.assertIsNone(task_blockers.detect(SIGNING, signing=False))
        self.assertEqual(task_blockers.detect(SIGNING)[0], "signing")

    def test_dispatcher_on_inari_asks_no_signing_question(self):
        with Workspace() as work:
            t3 = FakeT3()
            d = make_dispatcher(work.db(), t3)
            d.config["allowUnsignedCommits"] = True
            start(d, "a")
            t3.finish("thread-1", reply=SIGNING)
            d.tick()
            self.assertNotEqual(d.store.task("a")["blocked_kind"], "signing")
            self.assertFalse(any("blockiert" in n["body"] for n in work.notices(d)))


class SelectionTests(unittest.TestCase):
    def test_design_guidance_only_for_visible_work(self):
        self.assertNotIn("STYLE", task_prompt("Fix the nginx timeout", "STYLE"))
        self.assertIn("STYLE", task_prompt("Fix the menu layout on mobile", "STYLE"))

    def test_readonly_prompt_has_no_design_guidance(self):
        self.assertNotIn(
            "STYLE", task_prompt("Check the page layout", "STYLE", intent=READONLY)
        )

    def test_rules_appear_once(self):
        prompt = task_prompt("Fix the menu layout", "style", "GLOBAL")
        for phrase in ("exactly that SHA", "Never merge", "isolated branch"):
            self.assertEqual(prompt.count(phrase), 1, phrase)

    def test_unrelated_one_off_preference_is_left_out(self):
        smoke = entry("Authorizes one bounded Fable smoke test of orchestration")
        self.assertEqual(facts([smoke], "Fix the backup timer on inari"), "")

    def test_related_untagged_preference_is_kept(self):
        fact = entry("Orchestration changes go through isolated worktrees")
        self.assertIn("worktrees", facts([fact], "Change orchestration worktrees"))

    def test_topics_and_expiry_decide_relevance(self):
        always = entry("Use Fish syntax", topics=["*"])
        scoped = entry("Attach screenshots", topics=["layout"])
        expired = entry("Old test", topics=["*"], expires="2026-01-01")
        text = facts([always, scoped, expired], "Fix the backup timer")
        self.assertIn("Fish", text)
        self.assertNotIn("screenshots", text)
        self.assertNotIn("Old test", text)
        self.assertIn("screenshots", facts([scoped], "Fix the layout"))


if __name__ == "__main__":
    unittest.main()
