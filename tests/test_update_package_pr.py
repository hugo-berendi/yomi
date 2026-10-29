import importlib.util
import contextlib
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/ci/update-package-pr.py"
spec = importlib.util.spec_from_file_location("update_package_pr", SCRIPT)
publisher = importlib.util.module_from_spec(spec)


def pull(number, branch, *, repo="hugo-berendi/yomi", assignees=()):
    return {
        "number": number,
        "title": "chore: update packages",
        "state": "open",
        "base": {"ref": "main"},
        "head": {"ref": branch, "repo": {"full_name": repo}},
        "assignees": [{"login": name} for name in assignees],
    }


class Forgejo:
    repository = "hugo-berendi/yomi"

    def __init__(self, pulls=()):
        self.pulls = list(pulls)
        self.events = []
        self.fail_create = False

    def request(self, method, path, payload=None):
        self.events.append((method, path, payload))
        if method == "GET":
            page = int(path.split("page=")[1].split("&")[0])
            return [p.copy() for p in self.pulls if p["state"] == "open"][
                (page - 1) * 50 : page * 50
            ]
        if method == "POST" and path == "/pulls":
            if self.fail_create:
                raise RuntimeError("Forgejo unavailable")
            result = pull(len(self.pulls) + 100, payload["head"])
            result.update({key: payload[key] for key in ("title", "body")})
            result["assignees"] = [
                {"login": name} for name in payload.get("assignees", [])
            ]
            self.pulls.append(result)
            return result.copy()
        if method == "DELETE":
            return None
        if method == "PATCH":
            number = int(path.rsplit("/", 1)[1])
            result = next(p for p in self.pulls if p["number"] == number)
            result.update(payload)
            if "assignees" in payload:
                result["assignees"] = [{"login": name} for name in payload["assignees"]]
            return result.copy()
        return {}


class PublishTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not SCRIPT.exists():
            raise AssertionError("Package PR publisher is missing")
        spec.loader.exec_module(publisher)

    def publish(self, api, body="version 2"):
        return publisher.publish(api, body, lambda: api.events.append(("push",)))

    def test_repeated_runs_refresh_one_pr(self):
        api = Forgejo()
        self.publish(api, "version 2")
        self.publish(api, "version 3")
        self.assertEqual(len(api.pulls), 1)
        self.assertEqual(api.pulls[0]["body"], "version 3")
        self.assertEqual(api.pulls[0]["assignees"], [{"login": "hugo-berendi"}])

    def test_closes_legacy_prs_only_after_replacement_exists(self):
        api = Forgejo([pull(1, "update-packages/2026-10-19")])
        self.publish(api)
        self.assertEqual(api.pulls[0]["state"], "closed")
        self.assertEqual(api.pulls[1]["state"], "open")
        create = next(
            i for i, e in enumerate(api.events) if e[:2] == ("POST", "/pulls")
        )
        close = next(
            i for i, e in enumerate(api.events) if e[:2] == ("PATCH", "/pulls/1")
        )
        self.assertLess(create, close)

    def test_failed_replacement_preserves_old_prs(self):
        api = Forgejo([pull(1, "update-packages/2026-10-19")])
        api.fail_create = True
        with self.assertRaises(RuntimeError):
            self.publish(api)
        self.assertEqual(api.pulls[0]["state"], "open")

    def test_failed_push_preserves_old_prs(self):
        api = Forgejo([pull(1, "update-packages/2026-10-19")])

        def fail_push():
            raise RuntimeError("Push rejected")

        with self.assertRaises(RuntimeError):
            publisher.publish(api, "version 2", fail_push)
        self.assertEqual(len(api.pulls), 1)
        self.assertEqual(api.pulls[0]["state"], "open")

    def test_push_replaces_the_same_remote_branch(self):
        with tempfile.TemporaryDirectory() as directory, contextlib.chdir(directory):

            def git(*args):
                return subprocess.check_output(
                    ["git", *args], text=True, stderr=subprocess.DEVNULL
                ).strip()

            git("init", "--bare", "remote.git")
            git("init", "work")
            with contextlib.chdir("work"):
                git("config", "user.name", "Test")
                git("config", "user.email", "test@example.org")
                git("remote", "add", "origin", "../remote.git")
                git("commit", "--allow-empty", "-m", "version 2")
                publisher.push_branch()
                first = git("rev-parse", "HEAD")
                git("commit", "--amend", "--allow-empty", "-m", "version 3")
                publisher.push_branch()
                latest = git("rev-parse", "HEAD")
                self.assertNotEqual(first, latest)
                self.assertEqual(
                    git("ls-remote", "--heads", "origin"),
                    f"{latest}\trefs/heads/update-packages",
                )

    def test_cleanup_checks_all_pages_and_ignores_other_work(self):
        unrelated = [pull(n, "feature/test") for n in range(1, 52)]
        foreign = pull(52, "update-packages/2026-10-19", repo="other/yomi")
        protected = pull(53, "update-packages/2026-10-19", assignees=["welles"])
        api = Forgejo(
            [*unrelated, foreign, protected, pull(54, "update-packages/2026-10-19")]
        )
        self.publish(api)
        self.assertTrue(all(p["state"] == "open" for p in api.pulls[:53]))
        self.assertEqual(api.pulls[53]["state"], "closed")

    def test_protected_canonical_pr_prevents_push(self):
        api = Forgejo([pull(1, "update-packages", assignees=["welles"])])
        api.pulls[0]["title"] = "Reviewing package updates"
        with self.assertRaises(RuntimeError):
            self.publish(api)
        self.assertFalse(any(e[0] == "push" for e in api.events))
        self.assertEqual(api.pulls[0]["state"], "open")


class DecideTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec.loader.exec_module(publisher)

    def decide(self, **overrides):
        api = Forgejo()
        alerts = []
        pr = {
            "number": 7,
            "title": "chore: update flake inputs",
            "html_url": "https://git/pr/7",
        }
        verdict = dict(ci_ok=True, gate_ok=True, reasons=[], can_merge=True)
        verdict.update(overrides)
        result = publisher.decide(api, pr, "a" * 40, notify=alerts.append, **verdict)
        merges = [e for e in api.events if e[0] == "POST" and e[1].endswith("/merge")]
        return result, merges, alerts

    def test_merges_only_when_both_checks_agree(self):
        result, merges, alerts = self.decide()
        self.assertEqual(result, "merged")
        self.assertEqual(merges[0][2]["head_commit_id"], "a" * 40)
        self.assertTrue(merges[0][2]["merge_when_checks_succeed"])
        self.assertEqual(alerts, [])

    def test_any_single_no_notifies_instead_of_merging(self):
        for failing in ("ci_ok", "gate_ok", "can_merge"):
            with self.subTest(failing=failing):
                result, merges, alerts = self.decide(
                    **{failing: False}, reasons=["why"]
                )
                self.assertEqual(result, "notified")
                self.assertEqual(merges, [])
                self.assertEqual(alerts[0]["url"], "https://git/pr/7")
                self.assertIn("why", alerts[0]["message"])

    def test_notify_cancels_a_merge_scheduled_by_an_earlier_run(self):
        api = Forgejo()
        pr = {"number": 7, "title": "t", "html_url": "u"}
        publisher.decide(
            api,
            pr,
            "b" * 40,
            ci_ok=True,
            gate_ok=False,
            reasons=[],
            can_merge=True,
            notify=lambda event: None,
        )
        self.assertIn(("DELETE", "/pulls/7/merge", None), api.events)

    def test_announces_only_a_newly_opened_pr(self):
        announced = []
        fresh = Forgejo()
        publisher.publish(fresh, "body", lambda: None, announce=announced.append)
        self.assertEqual(len(announced), 1)
        existing = Forgejo([pull(1, "update-packages")])
        publisher.publish(existing, "body", lambda: None, announce=announced.append)
        self.assertEqual(len(announced), 1)

    def test_push_cancels_a_scheduled_merge_first(self):
        api = Forgejo([pull(1, "update-packages")])
        publisher.publish(api, "body", lambda: api.events.append(("push",)))
        cancel = api.events.index(("DELETE", "/pulls/1/merge", None))
        self.assertLess(cancel, api.events.index(("push",)))

    def test_unreadable_or_partial_verdicts_count_as_no(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "verdict.json"
            self.assertFalse(publisher.read_verdict(path, "ok")[0])
            for content in (
                "not json",
                "[]",
                '{"ok": "true"}',
                '{"ok": 1}',
                '{"safe": true}',
            ):
                path.write_text(content)
                self.assertFalse(publisher.read_verdict(path, "ok")[0], content)
            path.write_text('{"ok": true, "reasons": []}')
            self.assertTrue(publisher.read_verdict(path, "ok")[0])


if __name__ == "__main__":
    unittest.main()
