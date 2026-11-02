"""Exercise real T3 linking/settings in temporary empty homes, without model calls."""

import contextlib
import json
import os
import socket
import subprocess
import tempfile
import time
from pathlib import Path


RPC = Path(__file__).parents[1] / "hosts/nixos/inari/services/t3code-vm/rpc.mjs"


@contextlib.contextmanager
def server():
    with tempfile.TemporaryDirectory(prefix="yomi-t3-rpc-") as directory:
        root = Path(directory)
        env = {
            **os.environ,
            "HOME": directory,
            "XDG_CONFIG_HOME": str(root / "config"),
            "XDG_DATA_HOME": str(root / "data"),
            "CODEX_HOME": str(root / "codex"),
            "CLAUDE_CONFIG_DIR": str(root / "claude"),
        }
        with socket.socket() as listener:
            listener.bind(("127.0.0.1", 0))
            port = listener.getsockname()[1]
        command = ["t3"]
        with (root / "server.log").open("w") as log:
            process = subprocess.Popen(
                [
                    "t3",
                    "serve",
                    "--host",
                    "127.0.0.1",
                    "--port",
                    str(port),
                    "--base-dir",
                    str(root / "t3"),
                ],
                env=env,
                stdout=log,
                stderr=log,
            )
            try:
                for _ in range(100):
                    try:
                        with socket.create_connection(("127.0.0.1", port), timeout=0.2):
                            break
                    except OSError:
                        if process.poll() is not None:
                            raise RuntimeError("Temporary T3 exited")
                        time.sleep(0.2)
                else:
                    raise RuntimeError("Temporary T3 did not start")
                yield command, env, f"http://127.0.0.1:{port}"
            finally:
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()


def cli(instance, arguments):
    command, env, _ = instance
    result = subprocess.run(
        [*command, *arguments, "--base-dir", str(Path(env["HOME"]) / "t3")],
        env=env,
        capture_output=True,
        text=True,
    )
    if result.returncode:
        raise RuntimeError("Isolated T3 command failed; captured output suppressed")
    return result.stdout.strip()


def rpc(instance, token, operation, payload):
    result = subprocess.run(
        ["node", str(RPC)],
        input=json.dumps(
            {
                "baseUrl": instance[2],
                "token": token,
                "operation": operation,
                "input": payload,
            }
        ),
        capture_output=True,
        text=True,
        timeout=40,
    )
    if result.returncode:
        reason = next(
            (
                line
                for line in result.stderr.splitlines()
                if line.startswith("Error: RPC request failed:")
            ),
            "RPC transport failure",
        )
        raise RuntimeError(f"Isolated {operation} failed: {reason}")
    return json.loads(result.stdout)


def main():
    with server() as host, server() as guest:
        host_token = cli(
            host, ["auth", "session", "issue", "--token-only", "--ttl", "2m"]
        )
        guest_token = cli(
            guest, ["auth", "session", "issue", "--token-only", "--ttl", "2m"]
        )
        assert rpc(host, host_token, "peerLinks.list", {}) == {"links": []}
        rpc(
            host,
            host_token,
            "server.updateSettings",
            {"patch": {"linkedEnvironmentsEnabled": True}},
        )
        settings = rpc(
            guest,
            guest_token,
            "server.updateSettings",
            {
                "patch": {
                    "linkedEnvironmentsEnabled": True,
                    "providerInstances": {
                        "opencode": {"driver": "opencode", "enabled": False}
                    },
                },
            },
        )
        assert settings["providerInstances"]["opencode"]["enabled"] is False
        pairing = json.loads(
            cli(guest, ["auth", "pairing", "create", "--json", "--ttl", "2m"])
        )
        linked = rpc(
            host,
            host_token,
            "peerLinks.link",
            {
                "url": guest[2],
                "pairingCode": pairing["credential"],
                "access": "full-access",
            },
        )
        listed = rpc(host, host_token, "peerLinks.list", {})
        assert any(
            link["environmentId"] == linked["environmentId"] for link in listed["links"]
        )
        print("PASS: real T3 RPC settings update and one-way pairing/link discovery")


if __name__ == "__main__":
    main()
