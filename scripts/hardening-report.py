"""Report evaluated sandbox settings without modifying or activating any units."""

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("host")
    parser.add_argument(
        "--json", action="store_true", help="Save this output as a comparison baseline"
    )
    parser.add_argument("--baseline", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    result = subprocess.run(
        [
            "nix",
            "eval",
            "--impure",
            "--json",
            "--file",
            str(root / "scripts/hardening-report.nix"),
            "--apply",
            'report: report { host = builtins.getEnv "YOMI_REPORT_HOST"; }',
        ],
        capture_output=True,
        text=True,
        env=os.environ | {"YOMI_REPORT_HOST": args.host},
    )
    if result.returncode:
        print(result.stderr, file=sys.stderr, end="")
        raise SystemExit(result.returncode)
    report = json.loads(result.stdout)
    if args.baseline:
        previous = json.loads(args.baseline.read_text())
        changes = {}
        for name in sorted(previous.keys() | report.keys()):
            before = previous.get(name, {}).get("settings")
            after = report.get(name, {}).get("settings")
            if before != after:
                changes[name] = {"before": before, "after": after}
        print(json.dumps(changes, indent=2))
    elif args.json:
        print(json.dumps(report, indent=2))
    else:
        print(
            "Evaluated configuration, not the running generation. Unset directives may be implied by systemd."
        )
        for name, entry in report.items():
            print(f"\n{name}: {json.dumps(entry['settings'], sort_keys=True)}")
            for source in entry["definitionSources"]:
                print(f"  defined in {source}")
            print(f"  generated unit: {entry['unitFile']}")
            for note in entry["notes"]:
                print(f"  {note}")


if __name__ == "__main__":
    main()
