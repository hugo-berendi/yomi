"""Publish one rolling package-update PR and retire superseded dated PRs."""

import json
import os
from pathlib import Path
import subprocess
import sys
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


def publish(api, body, push):
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
                pr["head"]["ref"] == BRANCH
                or (pr["title"] == TITLE and pr["head"]["ref"].startswith(BRANCH + "/"))
            )
        )
        page += 1

    current = [pr for pr in candidates if pr["head"]["ref"] == BRANCH]
    if any(protected(pr) for pr in current):
        raise RuntimeError(
            "The rolling package PR is assigned to welles; leaving it unchanged"
        )

    push()
    payload = {"title": TITLE, "body": body}
    if current:
        pr = min(current, key=lambda item: item["number"])
        assignees = {user["login"] for user in pr.get("assignees") or []}
        payload["assignees"] = sorted(assignees | {"hugo-berendi"})
        api.request("PATCH", f"/pulls/{pr['number']}", payload)
    else:
        pr = api.request(
            "POST",
            "/pulls",
            {**payload, "head": BRANCH, "base": "main", "assignees": ["hugo-berendi"]},
        )
        api.request(
            "POST",
            f"/pulls/{pr['number']}/requested_reviewers",
            {"reviewers": ["hugo-berendi"]},
        )

    for old in candidates:
        if old["number"] != pr["number"] and not protected(old):
            api.request("PATCH", f"/pulls/{old['number']}", {"state": "closed"})
    print(f"Package updates published in PR #{pr['number']}")


def push_branch():
    ref = f"refs/heads/{BRANCH}"
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


if __name__ == "__main__":
    publish(Forgejo(), Path(sys.argv[1]).read_text(), push_branch)
