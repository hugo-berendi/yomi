"""Bounded readiness checks after activation; never roll back database migrations."""

import argparse
import json
import subprocess
import sys
import time
from urllib.error import URLError
from urllib.request import urlopen


def probe(check):
    if "command" in check:
        subprocess.run(check["command"], check=True, timeout=5, capture_output=True)
        return
    with urlopen(check["url"], timeout=5) as response:
        if "json" in check:
            actual = json.load(response)
            if not isinstance(actual, dict) or any(
                actual.get(key) != value for key, value in check["json"].items()
            ):
                raise RuntimeError("application health response failed")


def wait_healthy(checks, timeout, interval):
    deadline = time.monotonic() + timeout
    while True:
        failures = []
        for check in checks:
            try:
                probe(check)
            except (
                OSError,
                URLError,
                ValueError,
                RuntimeError,
                subprocess.SubprocessError,
            ) as error:
                failures.append(f"{check['name']} ({type(error).__name__})")
        if not failures:
            print(
                "Post-activation checks passed: " + ", ".join(c["name"] for c in checks)
            )
            return True
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            print(
                "Post-activation checks failed: " + ", ".join(failures), file=sys.stderr
            )
            return False
        time.sleep(min(interval, remaining))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("checks")
    parser.add_argument("--timeout", type=float, default=120)
    args = parser.parse_args()
    with open(args.checks) as handle:
        checks = json.load(handle)
    if not checks:
        parser.error("at least one readiness check is required")
    return 0 if wait_healthy(checks, args.timeout, 3) else 1


if __name__ == "__main__":
    sys.exit(main())
