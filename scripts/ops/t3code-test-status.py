"""Credential-free guest health projection from T3's supported config RPC."""

import json
import subprocess
from pathlib import Path


def main():
    token = subprocess.check_output(
        [
            "t3",
            "auth",
            "session",
            "issue",
            "--token-only",
            "--ttl",
            "1m",
            "--scope",
            "orchestration:read",
        ],
        text=True,
    ).strip()
    response = subprocess.run(
        [
            "node",
            str(Path(__file__).resolve().parents[1] / "share/rpc.mjs"),
        ],
        input=json.dumps(
            {
                "baseUrl": "http://10.231.0.2:3773",
                "token": token,
                "operation": "server.getConfig",
                "input": {},
            }
        ),
        text=True,
        capture_output=True,
        timeout=40,
    )
    if response.returncode:
        raise SystemExit("Guest T3 health query failed; credential output suppressed")
    config = json.loads(response.stdout)
    providers = [
        {
            "instanceId": provider["instanceId"],
            "enabled": provider["enabled"],
            "installed": provider["installed"],
            "version": provider["version"],
            "status": provider["status"],
            "authentication": provider["auth"]["status"],
            "checkedAt": provider["checkedAt"],
        }
        for provider in config["providers"]
    ]
    workspaces = subprocess.check_output(["t3code-test-workspace", "status"], text=True)
    print(
        json.dumps(
            {
                "role": "guest",
                "hostname": "t3code-vm",
                "t3_running": True,
                "environmentId": config["environment"]["environmentId"],
                "t3_version": config["environment"]["serverVersion"],
                "providers": providers,
                "workspaces": json.loads(workspaces),
            }
        )
    )


if __name__ == "__main__":
    main()
