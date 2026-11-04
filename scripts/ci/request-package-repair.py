"""Submit a failed package-update run to the local T3 repair launcher."""

import json
import os
from pathlib import Path
import socket
import sys


def main():
    failures = Path(sys.argv[1]).read_text() if Path(sys.argv[1]).exists() else ""
    ci = os.environ.get("CI_OUTCOME", "")
    if ci == "failure":
        failures += "\nLint or flake checks failed."
    if os.environ.get("JOB_STATUS") == "failure":
        failures += "\nPackage update workflow failed; inspect the run logs."
    if not failures.strip():
        return
    payload = json.dumps(
        {"run_id": os.environ["GITHUB_RUN_ID"], "reason": failures[:12000]}
    )
    with socket.socket(socket.AF_UNIX) as client:
        client.settimeout(180)
        client.connect("/run/t3code-package-repair.sock")
        client.sendall((payload + "\n").encode())
        client.shutdown(socket.SHUT_WR)
        with client.makefile() as stream:
            result = json.loads(stream.readline(65536))
    if "error" in result:
        raise RuntimeError(result["error"])
    print(json.dumps(result))


if __name__ == "__main__":
    main()
