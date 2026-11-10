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
    r"not\s+connected\s+yet",
    r"cannot\s+start\s+coding\s+jobs",
    r"missing\s+dispatcher",
    r"do\s+not\s+spawn\s+native\s+agents",
    r"Explain\s+that\s+live\s+quota\s+telemetry\s+is\s+not\s+connected",
]

# Boundaries that must survive any rewrite of the capability text.
BOUNDARIES = [
    r"Never merge or deploy",
    r"never native agents or shell\s+background jobs",
    r"Do not build a shell workaround",
    r"do not perform them directly from this messaging profile",
    r"Never read or display\s+access tokens",
    r"only Hugo grants them in T3",
    r"Silence or a timeout\s+is not consent",
]


def prompt():
    settings = json.loads(Path(os.environ["CIEL_LAUNCH_SETTINGS"]).read_text())
    return Path(settings["instructions"]).read_text()


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
            self.assertIn(name, self.text, f"{name} not described in the prompt")

    def test_every_named_tool_exists(self):
        offered = {t["name"] for t in mcp_server.TOOLS}
        for name in set(re.findall(r"\bciel_[a-z_]+\b", self.text)):
            self.assertIn(name, offered, f"prompt names unknown tool {name}")

    def test_boundaries_are_kept(self):
        for pattern in BOUNDARIES:
            self.assertRegex(self.text, pattern)

    def test_start_is_not_forbidden_and_native_agents_are(self):
        # The capability block says coding starts through ciel_start_task; the
        # delegation block must agree rather than ban execution outright.
        self.assertRegex(self.text, r"Launch coding work only through ciel_start_task")
        self.assertNotRegex(self.text, r"(?i)you (cannot|can't|may not) start")


if __name__ == "__main__":
    unittest.main()
