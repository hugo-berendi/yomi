"""Host transport for the isolated testing guest; never invokes host sudo."""

import argparse
import json
import os
import re
import shlex
import socket
import subprocess
import tempfile
from pathlib import Path


GUEST = "agent@10.231.0.2"
TOOL = "/opt/t3code-tools/bin/t3code-test-workspace"


def ssh(command, **kwargs):
    state = Path.home() / ".local/state/t3code-vm"
    return subprocess.run(
        [
            "ssh",
            "-o",
            "BatchMode=yes",
            "-o",
            "ConnectTimeout=5",
            "-o",
            "StrictHostKeyChecking=yes",
            "-o",
            f"UserKnownHostsFile={state / 'known_hosts'}",
            "-i",
            str(state / "ssh_key"),
            "--",
            GUEST,
            shlex.join(command),
        ],
        **kwargs,
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="action", required=True)
    commands.add_parser("status")
    prepare = commands.add_parser("prepare")
    prepare.add_argument("repo", type=Path)
    prepare.add_argument("--run-id", required=True)
    prepare.add_argument("--include-path", action="append", default=[])
    run = commands.add_parser("run")
    run.add_argument("--run-id", required=True)
    run.add_argument("--timeout", type=float, default=600)
    run.add_argument("command", nargs=argparse.REMAINDER)
    cleanup = commands.add_parser("cleanup")
    cleanup.add_argument("--run-id", required=True)
    args = parser.parse_args()
    if args.action == "status":
        if socket.gethostname() == "t3code-vm":
            os.execvp("t3code-test-status", ["t3code-test-status"])
        guest = ssh(
            ["/opt/t3code-tools/bin/t3code-test", "status"],
            capture_output=True,
            text=True,
        )
        links = subprocess.run(
            ["t3", "environment", "list", "--json"], capture_output=True, text=True
        )
        state = Path.home() / ".local/state/t3code-vm/bootstrap.json"
        print(
            json.dumps(
                {
                    "role": "host",
                    "bootstrap": json.loads(state.read_text())
                    if state.exists()
                    else None,
                    "guest_reachable": guest.returncode == 0,
                    "guest": json.loads(guest.stdout)
                    if guest.returncode == 0
                    else None,
                    "links": json.loads(links.stdout)
                    if links.returncode == 0
                    else None,
                }
            )
        )
        return
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,127}", args.run_id):
        parser.error("run-id must be a safe identifier")
    if args.action == "prepare":
        with tempfile.TemporaryDirectory(prefix="t3code-test-") as directory:
            archive = Path(directory) / "snapshot.tar"
            command = [
                "t3code-test-workspace",
                "prepare",
                str(args.repo),
                "--run-id",
                args.run_id,
                "--output",
                str(archive),
            ]
            for path in args.include_path:
                command += ["--include-path", path]
            subprocess.run(command, check=True)
            remote = f"/home/agent/.cache/t3code-test/{args.run_id}.tar"
            ssh(["mkdir", "-p", "/home/agent/.cache/t3code-test"], check=True)
            try:
                with archive.open("rb") as data:
                    ssh(
                        ["install", "-m", "600", "/dev/stdin", remote],
                        stdin=data,
                        check=True,
                    )
                ssh([TOOL, "receive", remote, "--run-id", args.run_id], check=True)
            finally:
                ssh(["rm", "-f", "--", remote], check=False)
        print(
            json.dumps(
                {
                    "run_id": args.run_id,
                    "guest_path": f"/home/agent/test-workspaces/{args.run_id}",
                }
            )
        )
        return
    if args.action == "cleanup":
        if socket.gethostname() == "t3code-vm":
            os.execvp(TOOL, [TOOL, "cleanup", "--run-id", args.run_id])
        raise SystemExit(ssh([TOOL, "cleanup", "--run-id", args.run_id]).returncode)
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not command:
        parser.error("run requires -- COMMAND")
    if socket.gethostname() == "t3code-vm":
        os.execvp(
            TOOL,
            [
                TOOL,
                "run",
                "--run-id",
                args.run_id,
                "--timeout",
                str(args.timeout),
                "--",
                *command,
            ],
        )
    raise SystemExit(
        ssh(
            [
                TOOL,
                "run",
                "--run-id",
                args.run_id,
                "--timeout",
                str(args.timeout),
                "--",
                *command,
            ]
        ).returncode
    )


if __name__ == "__main__":
    main()
