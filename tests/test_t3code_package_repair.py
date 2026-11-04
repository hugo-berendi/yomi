import importlib.util
import io
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest

PATH = Path(__file__).parents[1] / "hosts/nixos/inari/services/t3code-repair/launch.py"
SPEC = importlib.util.spec_from_file_location("repair", PATH)
repair = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(repair)


def pull(assignees=()):
    return {
        "base": {"ref": "main"},
        "head": {
            "ref": "update-packages",
            "sha": "a" * 40,
            "repo": {"full_name": "hugo-berendi/yomi"},
        },
        "assignees": [{"login": a} for a in assignees],
        "html_url": "https://git.example/hugo-berendi/yomi/pulls/1",
    }


class RepairTest(unittest.TestCase):
    def test_welles_prevents_any_checkout_or_launch(self):
        with self.assertRaisesRegex(ValueError, "welles"):
            repair.eligible_pr([pull(["welles"])], "hugo-berendi/yomi")

    def test_invalid_run_id_cannot_escape_state_directory(self):
        with self.assertRaises(ValueError):
            repair.request_json(
                io.StringIO(json.dumps({"run_id": "../escape", "reason": "failed"}))
            )

    def test_launch_uses_exact_provider_effort_and_reuses_completed_request(self):
        with tempfile.TemporaryDirectory() as directory:
            args = SimpleNamespace(
                state_dir=directory,
                repository="hugo-berendi/yomi",
                remote="fixed-remote",
                t3_base_dir="/home/pilot/.t3",
                forgejo="https://git.example",
            )
            calls = []

            def run(*argv):
                calls.append(argv)
                if "rev-parse" in argv:
                    return "a" * 40
                if "start" in argv:
                    return '{"threadId":"repair-thread","link":"t3-thread://repair"}'
                return ""

            request = {"run_id": "123", "reason": "patch conflict"}
            result = repair.launch(args, request, [pull()], run=run)
            launch = next(c for c in calls if "start" in c)
            for flag, value in [
                ("--provider", "codex"),
                ("--model", "gpt-6.1-sol"),
                ("--reasoning-effort", "medium"),
                ("--runtime-mode", "full-access"),
            ]:
                self.assertEqual(launch[launch.index(flag) + 1], value)
            self.assertIn("never force push", launch[4])
            count = len(calls)
            self.assertEqual(repair.launch(args, request, [pull()], run=run), result)
            self.assertEqual(len(calls), count)

    def test_moved_pr_head_stops_before_starting_agent(self):
        with tempfile.TemporaryDirectory() as directory:
            args = SimpleNamespace(
                state_dir=directory,
                repository="hugo-berendi/yomi",
                remote="fixed-remote",
            )
            calls = []

            def run(*argv):
                calls.append(argv)
                return "b" * 40 if "rev-parse" in argv else ""

            with self.assertRaisesRegex(ValueError, "head changed"):
                repair.launch(
                    args, {"run_id": "124", "reason": "failed"}, [pull()], run=run
                )
            self.assertFalse(any("start" in call for call in calls))

    def test_retries_a_transient_project_startup_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            args = SimpleNamespace(
                state_dir=directory,
                repository="hugo-berendi/yomi",
                remote="fixed-remote",
                t3_base_dir="/home/pilot/.t3",
                forgejo="https://git.example",
            )
            offline = True
            starts = []

            def run(*argv):
                if "clone" in argv:
                    Path(argv[-1]).mkdir()
                if "rev-parse" in argv:
                    return "a" * 40
                if "t3" == argv[0] and offline:
                    raise RuntimeError("server is not ready")
                if "start" in argv:
                    starts.append(argv)
                    return '{"threadId":"repair-thread"}'
                return "[]" if "list" in argv else ""

            request = {"run_id": "125", "reason": "failed"}
            with self.assertRaisesRegex(RuntimeError, "not ready"):
                repair.launch(args, request, [pull()], run=run)
            offline = False
            self.assertEqual(
                repair.launch(args, request, [pull()], run=run)["threadId"],
                "repair-thread",
            )
            self.assertEqual(len(starts), 1)

    def test_recovers_the_accepted_thread_after_losing_its_launch_response(self):
        with tempfile.TemporaryDirectory() as directory:
            args = SimpleNamespace(
                state_dir=directory,
                repository="hugo-berendi/yomi",
                remote="fixed-remote",
                t3_base_dir="/home/pilot/.t3",
                forgejo="https://git.example",
            )
            starts = []

            def run(*argv):
                if "clone" in argv:
                    Path(argv[-1]).mkdir()
                if "rev-parse" in argv:
                    return "a" * 40
                if "start" in argv:
                    starts.append(argv)
                    raise RuntimeError("response lost")
                if "list" in argv:
                    return '[{"threadId":"accepted-thread","title":"Repair package update 126"}]'
                return ""

            request = {"run_id": "126", "reason": "failed"}
            with self.assertRaisesRegex(RuntimeError, "response lost"):
                repair.launch(args, request, [pull()], run=run)
            self.assertEqual(
                repair.launch(args, request, [pull()], run=run)["threadId"],
                "accepted-thread",
            )
            self.assertEqual(len(starts), 1)

    def test_all_failed_updates_prepare_the_pr_branch_when_no_pr_exists(self):
        with tempfile.TemporaryDirectory() as directory:
            args = SimpleNamespace(
                state_dir=directory,
                repository="hugo-berendi/yomi",
                remote="fixed-remote",
                t3_base_dir="/home/pilot/.t3",
                forgejo="https://git.example",
            )
            calls = []

            def run(*argv):
                calls.append(argv)
                if "rev-parse" in argv:
                    return "a" * 40
                return '{"threadId":"repair"}' if "start" in argv else ""

            repair.launch(
                args, {"run_id": "127", "reason": "every update failed"}, [], run=run
            )
            switch = next(i for i, call in enumerate(calls) if "switch" in call)
            start = next(i for i, call in enumerate(calls) if "start" in call)
            self.assertLess(switch, start)
            self.assertEqual(calls[switch][-2:], ("-c", "update-packages"))
            self.assertIn("Create the rolling update-packages PR", calls[start][4])
