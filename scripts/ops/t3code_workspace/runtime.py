import json
import os
import re
import shutil
import signal
import subprocess
from pathlib import Path

from .core import WorkspaceError, _lock


def _workspace(root, run_id):
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,127}", run_id):
        raise WorkspaceError("run-id must be a safe identifier")
    root = Path(root).resolve()
    workspace = root / run_id
    if workspace.parent != root or workspace.is_symlink() or not workspace.is_dir():
        raise WorkspaceError(f"workspace does not exist: {run_id}")
    return workspace


def run(root, run_id, timeout, command):
    workspace = _workspace(root, run_id)
    root = Path(root)
    with _lock(root / ".workspace.lock"):
        metadata = workspace / ".git/t3-test"
        active = metadata / "run.active"
        active.write_text(
            json.dumps({"pid": os.getpid(), "run_id": run_id}), encoding="utf-8"
        )
        timed_out = False
        process = None
        try:
            with (
                (metadata / "stdout.log").open("wb") as stdout,
                (metadata / "stderr.log").open("wb") as stderr,
            ):
                process = subprocess.Popen(
                    command,
                    cwd=workspace,
                    stdout=stdout,
                    stderr=stderr,
                    start_new_session=True,
                )
                try:
                    exit_code = process.wait(timeout=timeout)
                except subprocess.TimeoutExpired:
                    timed_out = True
                    os.killpg(process.pid, signal.SIGTERM)
                    try:
                        exit_code = process.wait(timeout=2)
                    except subprocess.TimeoutExpired:
                        os.killpg(process.pid, signal.SIGKILL)
                        exit_code = process.wait()
        finally:
            if process is not None:
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
            active.unlink(missing_ok=True)
        result = {
            "run_id": run_id,
            "exit_code": exit_code,
            "timed_out": timed_out,
            "command": list(command),
        }
        (metadata / "run.json").write_text(
            json.dumps(result, sort_keys=True), encoding="utf-8"
        )
        return result


def status(root):
    root = Path(root).resolve()
    result = []
    if not root.is_dir():
        return result
    for child in sorted(root.iterdir()):
        if child.name.startswith(".") or child.is_symlink() or not child.is_dir():
            continue
        manifest = child / ".git/t3-test/manifest.json"
        if manifest.is_file():
            data = json.loads(manifest.read_text(encoding="utf-8"))
            result.append(
                {
                    "run_id": child.name,
                    "commit": data.get("commit"),
                    "active": (child / ".git/t3-test/run.active").exists(),
                }
            )
    return result


def cleanup(root, run_id):
    workspace = _workspace(root, run_id)
    with _lock(Path(root) / ".workspace.lock"):
        shutil.rmtree(workspace)
