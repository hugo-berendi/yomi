import json
import logging
import os
from pathlib import Path
import socketserver
import stat
import sys
import time

from dispatch_core import Dispatcher
from dispatch_store import Store
from t3_rpc import T3Rpc
from t3_mcp import NativeMcp
from t3_mcp_auth import McpAuth
from t3_backend import T3Backend
from pr_verification import AsyncVerifier
from task_scheduler import TICK


def main():
    os.umask(0o077)
    logging.basicConfig(level=logging.INFO)
    config = json.loads(Path(sys.argv[1]).read_text())
    config["environmentId"] = (
        (Path(config["baseDirectory"]) / "userdata/environment-id").read_text().strip()
    )
    config["globalRules"] = (
        Path(config["globalInstructionFile"])
        .read_text()
        .split("<!-- BEGIN ", 1)[0]
        .strip()
    )
    root = Path(config["stateDirectory"])
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    store = Store(root / "tasks.sqlite")
    backend = T3Backend(NativeMcp(config, McpAuth(config), store), T3Rpc(config))
    # Forge reads get their own T3 session and worker threads: a slow forge must
    # not delay the next look at any task's questions.
    dispatcher = Dispatcher(
        config, store, backend, verifier=AsyncVerifier(T3Rpc(config))
    )
    path = Path(config["socket"])
    if path.exists():
        if not stat.S_ISSOCK(path.stat().st_mode):
            raise ValueError("Refusing to remove non-socket broker path")
        path.unlink()

    class Handler(socketserver.StreamRequestHandler):
        def handle(self):
            self.request.settimeout(45)
            try:
                raw = self.rfile.readline(65537)
                if len(raw) > 65536:
                    raise ValueError("Request too large")
                req = json.loads(raw)
                result = {
                    "result": dispatcher.handle(
                        req["operation"], req.get("arguments", {})
                    )
                }
            except ValueError as exc:
                result = {"error": str(exc)}
            except Exception as exc:
                logging.error("Ciel broker request failed: %s", type(exc).__name__)
                result = {
                    "error": "T3 request failed; no success has been assumed. Retry with the same operation key."
                }
            self.wfile.write(json.dumps(result).encode() + b"\n")

    with socketserver.UnixStreamServer(str(path), Handler) as server:
        server.timeout = 1
        next_poll = 0
        while True:
            server.handle_request()
            if time.monotonic() >= next_poll:
                try:
                    dispatcher.tick(paced=True)
                except Exception as exc:
                    logging.warning("Ciel task poll deferred: %s", type(exc).__name__)
                next_poll = time.monotonic() + TICK


if __name__ == "__main__":
    main()
