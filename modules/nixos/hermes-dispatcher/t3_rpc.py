"""Short-lived scoped T3 sessions; credentials only cross private subprocess stdin."""

import json
import subprocess
import time


class T3Rpc:
    def __init__(self, config):
        self.config = config
        self.token = None
        self.expires = 0

    def __call__(self, operation, payload=None, *, first=False):
        if operation not in {
            "subscribeServerConfig",
            "pullRequests.detail",
            "pullRequests.activity",
            "pullRequests.summary",
        }:
            raise ValueError(
                "Internal API supplement permits only quota and forge reads"
            )
        if time.monotonic() >= self.expires:
            result = subprocess.run(
                [
                    self.config["t3"],
                    "auth",
                    "session",
                    "issue",
                    "--base-dir",
                    self.config["baseDirectory"],
                    "--token-only",
                    "--ttl",
                    "5m",
                    "--label",
                    "Ciel dispatcher",
                    "--scope",
                    "orchestration:read",
                ],
                check=True,
                capture_output=True,
                text=True,
                timeout=20,
            )
            self.token = result.stdout.strip()
            self.expires = time.monotonic() + 240
        result = subprocess.run(
            [self.config["node"], self.config["rpcScript"]],
            input=json.dumps(
                {
                    "baseUrl": self.config["baseUrl"],
                    "token": self.token,
                    "operation": operation,
                    "input": payload or {},
                    "firstChunk": first,
                }
            ),
            check=False,
            capture_output=True,
            text=True,
            timeout=40,
        )
        if result.returncode:
            # Transport errors never include credential-bearing stdin or full server replies.
            raise RuntimeError(
                "T3 RPC failed; inspect the broker service and T3 availability"
            )
        return json.loads(result.stdout)
