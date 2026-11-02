import argparse
import json
from pathlib import Path

from .core import prepare, receive
from .runtime import cleanup, run, status


def main():
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="action", required=True)
    prepare_parser = subparsers.add_parser("prepare")
    prepare_parser.add_argument("repo", type=Path)
    prepare_parser.add_argument("--run-id", required=True)
    prepare_parser.add_argument("--output", required=True, type=Path)
    prepare_parser.add_argument("--include-path", action="append", default=[])
    receive_parser = subparsers.add_parser("receive")
    receive_parser.add_argument("archive", type=Path)
    receive_parser.add_argument(
        "--root", type=Path, default=Path("/home/agent/test-workspaces")
    )
    receive_parser.add_argument("--run-id", required=True)
    run_parser = subparsers.add_parser("run")
    run_parser.add_argument(
        "--root", type=Path, default=Path("/home/agent/test-workspaces")
    )
    run_parser.add_argument("--run-id", required=True)
    run_parser.add_argument("--timeout", required=True, type=float)
    run_parser.add_argument("command", nargs=argparse.REMAINDER)
    status_parser = subparsers.add_parser("status")
    status_parser.add_argument(
        "--root", type=Path, default=Path("/home/agent/test-workspaces")
    )
    cleanup_parser = subparsers.add_parser("cleanup")
    cleanup_parser.add_argument(
        "--root", type=Path, default=Path("/home/agent/test-workspaces")
    )
    cleanup_parser.add_argument("--run-id", required=True)
    args = parser.parse_args()
    try:
        if args.action == "prepare":
            prepare(args.repo, args.run_id, args.output, args.include_path)
            return
        if args.action == "receive":
            receive(args.archive, args.root, args.run_id)
            return
        if args.action == "run":
            command = args.command[1:] if args.command[:1] == ["--"] else args.command
            if not command:
                parser.error("run requires -- <command>")
            result = run(args.root, args.run_id, args.timeout, command)
            print(json.dumps(result, sort_keys=True))
            if result["timed_out"]:
                raise SystemExit(124)
            raise SystemExit(
                result["exit_code"]
                if result["exit_code"] >= 0
                else 128 - result["exit_code"]
            )
            return
        if args.action == "status":
            print(json.dumps(status(args.root), sort_keys=True))
            return
        cleanup(args.root, args.run_id)
    except Exception as error:
        parser.exit(1, f"error: {error}\n")
