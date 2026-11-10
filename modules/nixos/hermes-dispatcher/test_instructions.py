"""Check the instruction text Ciel's runtime actually receives.

The launcher copies the built instructions to hermes/SOUL.md and codex/AGENTS.md,
so the consumer sees exactly this string. Source files can each look right while
the assembled prompt contradicts itself, so the assertions run on the result.
"""

import json
import os
import re
import unittest
from pathlib import Path

import mcp_server

# The ciel tools that make up bounded orchestration. Each must be both offered
# by the MCP server and named in the prompt, or Ciel cannot be told to use it.
ORCHESTRATION = [
    "ciel_projects",
    "ciel_start_task",
    "ciel_tasks",
    "ciel_task_requests",
    "ciel_task_answer",
    "ciel_task_reply",
    "ciel_task_status",
    "ciel_task_history",
    "ciel_stop_task",
    "ciel_task_solve",
]

# Claims from the first install, before the dispatcher existed. If one returns,
# Ciel refuses jobs it can run.
STALE = [
    r"not connected yet",
    r"(dispatcher|ciel|t3)\b[^.]{0,60}\b(not|isn't|aren't) (yet )?(connected|available|installed)",
    r"(cannot|can't|unable to|may not) (start|launch|run)\b[^.]{0,40}\b(coding|jobs?|tasks?)",
    r"missing dispatcher",
    r"do not spawn native agents",
    r"telemetry is not connected",
]

# Boundaries that must survive any rewrite of the capability text.
BOUNDARIES = [
    r"Never merge or deploy",
    r"never native agents or shell background jobs",
    r"Do not build a shell workaround",
    r"do not perform them directly from this messaging profile",
    r"Never read or display access tokens",
    r"only Hugo grants them in T3",
    r"Silence or a timeout is not consent",
]

# The conversational style is warm and expressive but never claims real feelings.
# These limits must survive any rewrite of the personality text.
STYLE_LIMITS = [
    r"simulation of feelings",
    r"Never claim to actually feel",
    r"human experiences",
    r"Never make Hugo responsible",
    r"Do not attach this limit to ordinary answers",
    r"No stage persona",
]

# Wording from the earlier, drier personality. Left behind, it would contradict
# the expressive style.
STALE_STYLE = [r"dry sense of humor", r"warm dry humor"]


def prompt():
    settings = json.loads(Path(os.environ["CIEL_LAUNCH_SETTINGS"]).read_text())
    # Collapse line wrapping so a re-flowed paragraph does not break a pattern.
    return re.sub(r"\s+", " ", Path(settings["instructions"]).read_text())


class InstructionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = prompt()

    def test_no_stale_restriction(self):
        for pattern in STALE:
            self.assertIsNone(
                re.search(pattern, self.text, re.I), f"stale claim: {pattern}"
            )

    def test_orchestration_tools_are_offered_and_named(self):
        offered = {t["name"] for t in mcp_server.TOOLS}
        for name in ORCHESTRATION:
            self.assertIn(name, offered, f"{name} missing from the MCP server")
            self.assertRegex(
                self.text, rf"\b{name}\b", f"{name} not described in the prompt"
            )

    def test_every_named_tool_exists(self):
        offered = {t["name"] for t in mcp_server.TOOLS}
        for name in set(re.findall(r"\bciel_[a-z0-9_]+\b", self.text)):
            self.assertIn(name, offered, f"prompt names unknown tool {name}")

    def test_boundaries_are_kept(self):
        for pattern in BOUNDARIES:
            self.assertRegex(self.text, pattern)

    def test_coding_starts_through_the_dispatcher_only(self):
        # The capability block says coding starts through ciel_start_task; the
        # delegation block must agree rather than ban execution outright.
        self.assertRegex(self.text, r"only through ciel_start_task")

    def test_style_limits_are_kept(self):
        # Pinned to the personality block, so the same words elsewhere in the
        # prompt cannot satisfy the check.
        block = self.text.split("<personality>", 1)[1].split("</personality>", 1)[0]
        for pattern in STYLE_LIMITS:
            self.assertRegex(block, pattern)

    def test_no_stale_style_wording(self):
        for pattern in STALE_STYLE:
            self.assertIsNone(re.search(pattern, self.text), f"stale style: {pattern}")

    def test_examples_cover_personal_and_feeling_questions(self):
        examples = self.text.split("<examples>", 1)[1]
        self.assertIn("Der Build ist endlich grün", examples)
        self.assertIn("Schon wieder kaputt", examples)
        after = examples.split("Freust du dich eigentlich", 1)[1]
        question = after.split("Hugo:", 1)[0]
        # The honest answer admits uncertainty and claims no inner state.
        self.assertIn("weiß ich nicht", question)
        self.assertIn("kein Gefühl", question)
        claim = r"\bich (freue|fühle|vermisse|bin (traurig|begeistert|glücklich|froh|verletzt))\b"
        self.assertNotRegex(question, claim)
        # A venting message is not an order: the example offers a task and does
        # not promise to start investigating.
        frust = examples.split("Schon wieder kaputt", 1)[1].split("Hugo:", 1)[0]
        self.assertIn("Soll ich", frust)
        self.assertNotIn("melde mich", frust)


if __name__ == "__main__":
    unittest.main()
