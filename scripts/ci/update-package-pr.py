"""Publish one rolling update PR, then merge it or ask a human.

Used by both update workflows: update-packages and update-flake-inputs.
The merge decision needs two independent yeses: the job's own CI run and
scripts/ci/update-gate.py (deterministic). Anything else sends a notification
through the local alert router with the PR link and leaves the PR open. A PR
that was just opened is announced the same way, merged or not.
"""

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
from urllib.error import HTTPError
from urllib.request import Request, urlopen


BRANCH = "update-packages"
TITLE = "chore: update packages"


class Forgejo:
    def __init__(self):
        self.repository = os.environ["GITHUB_REPOSITORY"]
        self.url = f"{os.environ['GITHUB_API_URL']}/repos/{self.repository}"
        self.token = os.environ["GITHUB_TOKEN"]

    def request(self, method, path, payload=None):
        request = Request(
            self.url + path,
            method=method,
            data=json.dumps(payload).encode() if payload is not None else None,
            headers={
                "Authorization": f"token {self.token}",
                "Content-Type": "application/json",
            },
        )
        with urlopen(request, timeout=60) as response:
            body = response.read()
            return json.loads(body) if body else None


def protected(pr):
    return any(user["login"] == "welles" for user in pr.get("assignees") or [])


def publish(api, body, push, branch=BRANCH, title=TITLE, announce=None):
    # Collect every page before closing anything: changing the open set while
    # paginating would shift later pages and silently skip old PRs.
    candidates = []
    page = 1
    while True:
        pulls = api.request("GET", f"/pulls?state=open&page={page}&limit=50")
        if not pulls:
            break
        candidates.extend(
            pr
            for pr in pulls
            if pr["base"]["ref"] == "main"
            and (pr["head"].get("repo") or {}).get("full_name") == api.repository
            and (
                pr["head"]["ref"] == branch
                or (pr["title"] == title and pr["head"]["ref"].startswith(branch + "/"))
            )
        )
        page += 1

    current = [pr for pr in candidates if pr["head"]["ref"] == branch]
    if any(protected(pr) for pr in current):
        raise RuntimeError(
            f"The rolling {branch} PR is assigned to welles; leaving it unchanged"
        )

    # A merge scheduled by an earlier run would otherwise apply to whatever
    # this push puts on the branch, without this run's checks.
    for pr in current:
        cancel_auto_merge(api, pr["number"])
    push()
    payload = {"title": title, "body": body}
    if current:
        pr = min(current, key=lambda item: item["number"])
        assignees = {user["login"] for user in pr.get("assignees") or []}
        payload["assignees"] = sorted(assignees | {"hugo-berendi"})
        api.request("PATCH", f"/pulls/{pr['number']}", payload)
    else:
        pr = api.request(
            "POST",
            "/pulls",
            {**payload, "head": branch, "base": "main", "assignees": ["hugo-berendi"]},
        )
        api.request(
            "POST",
            f"/pulls/{pr['number']}/requested_reviewers",
            {"reviewers": ["hugo-berendi"]},
        )
        if announce:
            announce(pr)

    for old in candidates:
        if old["number"] != pr["number"] and not protected(old):
            api.request("PATCH", f"/pulls/{old['number']}", {"state": "closed"})
    print(f"Updates published in PR #{pr['number']}", file=sys.stderr)
    return pr


def push_branch(branch=BRANCH):
    ref = f"refs/heads/{branch}"
    remote = subprocess.check_output(["git", "ls-remote", "origin", ref], text=True)
    previous = remote.split()[0] if remote.strip() else ""
    subprocess.run(
        [
            "git",
            "push",
            f"--force-with-lease={ref}:{previous}",
            "origin",
            f"HEAD:{ref}",
        ],
        check=True,
    )


def cancel_auto_merge(api, number):
    try:
        api.request("DELETE", f"/pulls/{number}/merge")
    except HTTPError as error:
        if error.code != 404:  # 404: nothing was scheduled
            raise


def read_verdict(path, key):
    """Read one gate's JSON output; anything unreadable counts as a no."""
    try:
        data = json.loads(Path(path).read_text())
    except (OSError, ValueError) as error:
        return False, [f"{path} unreadable: {error}"]
    if not isinstance(data, dict) or data.get(key) is not True:
        reasons = data.get("reasons") if isinstance(data, dict) else None
        reason = data.get("reason") if isinstance(data, dict) else None
        return False, [str(r) for r in reasons or [reason or f"{key} is not true"]]
    return True, []


def decide(api, pr, head, *, ci_ok, gate_ok, reasons, can_merge, notify):
    """Merge only when every check said yes; otherwise hand the PR to a human."""
    if ci_ok and gate_ok and can_merge:
        # head_commit_id pins the merge to the commit the checks looked at;
        # Forgejo refuses if the branch moved. merge_when_checks_succeed
        # additionally waits for the PR's own CI run and branch protection.
        api.request(
            "POST",
            f"/pulls/{pr['number']}/merge",
            {
                "Do": "merge",
                "head_commit_id": head,
                "merge_when_checks_succeed": True,
                "delete_branch_after_merge": True,
            },
        )
        return "merged"
    cancel_auto_merge(api, pr["number"])
    failed = [name for name, ok in (("CI", ci_ok), ("gate", gate_ok)) if not ok]
    if not failed and not can_merge:
        reasons = [*reasons, "auto-merge is off: UPDATE_BOT_TOKEN is not set"]
    notify(
        {
            "source": "updates",
            "severity": "warning",
            "event": True,
            "title": f"{pr.get('title', 'update')} needs review",
            "message": (
                (f"Not auto-merged: {', '.join(failed)} said no.\n\n" if failed else "")
                + "\n".join(f"- {r}" for r in reasons)[:1500]
            ),
            "url": pr.get("html_url"),
            "fingerprint": f"update-pr:{pr['number']}:{head[:12]}",
        }
    )
    return "notified"


def announce_new(pr):
    """Tell a human a fresh update PR exists; never fail the run over it."""
    try:
        post_alert(
            {
                "source": "updates",
                "severity": "info",
                "event": True,
                "title": f"New PR: {pr.get('title', 'update')}",
                "message": f"#{pr['number']} was opened and is being checked.",
                "url": pr.get("html_url"),
                "fingerprint": f"update-pr-new:{pr['number']}",
            }
        )
    except OSError as error:
        print(f"New-PR notification failed: {error}", file=sys.stderr)


def post_alert(event):
    url = os.environ.get("ALERT_ROUTER_URL", "http://127.0.0.1:8508/alert")
    request = Request(
        url,
        data=json.dumps([event]).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urlopen(request, timeout=30) as response:
        response.read()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("body", help="file with the PR description")
    parser.add_argument("--branch", default=BRANCH)
    parser.add_argument("--title", default=TITLE)
    parser.add_argument(
        "--ci-outcome", help="outcome of the job's own lint and check steps"
    )
    parser.add_argument("--gate", help="JSON written by update-gate.py")
    # The verdict as recorded in the step output right after the gate ran.
    # The JSON file sits in a directory later steps could write to, so it
    # only supplies the reasons; a merge needs both sources to say yes.
    parser.add_argument("--gate-ok", default="false")
    args = parser.parse_args(argv)

    api = Forgejo()
    pr = publish(
        api,
        Path(args.body).read_text(),
        lambda: push_branch(args.branch),
        branch=args.branch,
        title=args.title,
        announce=announce_new,
    )
    if args.ci_outcome is None:
        return 0
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
    ci_ok = args.ci_outcome == "success"
    gate_ok, gate_reasons = (
        read_verdict(args.gate, "ok") if args.gate else (False, ["gate did not run"])
    )
    gate_ok = gate_ok and args.gate_ok == "true"
    reasons = ([] if ci_ok else [f"CI outcome: {args.ci_outcome}"]) + gate_reasons
    result = decide(
        api,
        pr,
        head,
        ci_ok=ci_ok,
        gate_ok=gate_ok,
        reasons=reasons,
        can_merge=bool(os.environ.get("UPDATE_BOT_TOKEN")),
        notify=post_alert,
    )
    print(f"PR #{pr['number']}: {result}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
