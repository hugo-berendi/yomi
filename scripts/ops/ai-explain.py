"""Show what each agent harness gets: instruction blocks, skills and models.

Reads the evaluated Home Manager configuration. On the machine it runs on it
also reads the instruction files themselves and reports blocks that are
missing, stale or written by something else.
"""

import argparse
import getpass
import json
import re
import socket
import subprocess
from pathlib import Path

APPLY = """cfg: let
  ai = cfg.yomi.ai;
in {
  inherit (ai) models skillsCheckout instructionFiles legacyMarkers;
  home = cfg.home.homeDirectory;
  blocks = builtins.mapAttrs (_: b: {
    inherit (b) enable harnesses text;
    source = toString b.source;
  }) ai.instructions;
  skills = cfg.skills.resolved;
  targets = builtins.mapAttrs (_: t: t.dir) (builtins.removeAttrs cfg.skills.targets
    (builtins.filter (n: !cfg.skills.targets.${n}.enable) (builtins.attrNames cfg.skills.targets)));
}"""

MARKER = re.compile(r"<!-- BEGIN (.+?) -->\n(.*?)\n<!-- END \1 -->", re.S)


def evaluate(host, user):
    attr = f".#nixosConfigurations.{host}.config.home-manager.users.{user}"
    out = subprocess.run(
        ["nix", "eval", "--json", attr, "--apply", APPLY],
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    return json.loads(out)


def relative(source):
    return source.split("-source/", 1)[-1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("host", nargs="?", default=socket.gethostname())
    parser.add_argument("--user", default=getpass.getuser())
    args = parser.parse_args()
    cfg = evaluate(args.host, args.user)
    local = args.host == socket.gethostname()

    print(f"Models on {args.host} (yomi.ai.models):")
    for provider, roles in cfg["models"].items():
        print(f"  {provider}: " + ", ".join(f"{r}={m}" for r, m in roles.items()))
    checkout = cfg["skillsCheckout"]
    print(
        "Skills: live from " + checkout
        if checkout
        else "Skills: pinned flake input (just bump-skills)"
    )

    problems = 0
    for harness, file in cfg["instructionFiles"].items():
        wanted = {
            name: b
            for name, b in cfg["blocks"].items()
            if b["enable"] and harness in b["harnesses"]
        }
        print(f"\n{harness}: ~/{file}")
        for name, b in wanted.items():
            print(f"  block {name:<12} {relative(b['source'])}")
        if harness in cfg["targets"]:
            count = sum(harness in h for h in cfg["skills"].values())
            print(f"  skills       {count} in ~/{cfg['targets'][harness]}")
        if not local:
            continue
        path = Path(cfg["home"]) / file
        found = dict(MARKER.findall(path.read_text())) if path.exists() else {}
        for name, b in wanted.items():
            text = found.pop(f"YOMI {name}", None)
            if text is None:
                problems += 1
                print(f"  ! {name} is missing: run `just ai-sync`")
            elif text.strip() != b["text"].strip():
                problems += 1
                print(f"  ! {name} differs from the evaluated text: run `just ai-sync`")
        for marker in found:
            stale = marker.startswith("YOMI ") or marker in cfg["legacyMarkers"]
            problems += stale
            note = "stale, run `just ai-sync`" if stale else "written by another tool"
            print(f"  {'!' if stale else '-'} {marker}: {note}")
    if local:
        print("\nAll blocks current." if not problems else f"\n{problems} problem(s).")
    raise SystemExit(1 if problems else 0)


if __name__ == "__main__":
    main()
