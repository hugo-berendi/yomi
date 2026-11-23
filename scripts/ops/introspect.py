"""Answer "where is this set?" and "what does this service bring?" from the
evaluated configuration instead of from grep.

    introspect.py where OPTION.PATH [--host HOST]
    introspect.py explain SERVICE [--host HOST]

where   lists every file that defines an option, with the value it sets.
        The path may go below an attribute-set option, e.g.
        yomi.web.at.mealie.port.
explain shows what one service contributes to a host: ports, HTTP endpoints,
        LAN grants, Pangolin resources, units, containers, secrets, state and
        backups. SERVICE is a name under hosts/nixos/<host>/services/ or any
        repository path.

Both evaluate the working tree as the flake sees it (tracked files only).
"""

import argparse
import json
import pathlib
import socket
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
QUERIES = pathlib.Path(__file__).resolve().with_name("introspect.nix")


def evaluate(host, call):
    expr = f"""
      let
        flake = builtins.getFlake "git+file://{ROOT}";
        system = flake.nixosConfigurations.{json.dumps(host)};
        q = import {QUERIES} {{ inherit (flake.inputs.nixpkgs) lib; }};
      in {call}
    """
    result = subprocess.run(
        ["nix", "eval", "--impure", "--json", "--accept-flake-config", "--expr", expr],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        lines = [
            line
            for line in result.stderr.splitlines()
            if "error" in line or line.startswith("       ")
        ]
        sys.exit("\n".join(lines[-12:]) or result.stderr)
    return json.loads(result.stdout)


def short(value):
    text = json.dumps(value) if not isinstance(value, str) else value
    return text if len(text) <= 140 else text[:140] + " …"


def where(args):
    path = "[ " + " ".join(json.dumps(part) for part in args.option.split(".")) + " ]"
    data = evaluate(
        args.host, f"q.where {{ inherit (system) options; path = {path}; }}"
    )
    print(f"{data['option']}  (declared in {', '.join(data['declared']) or 'nixpkgs'})")
    if not data["definitions"]:
        print("  no definition on this host; the default applies")
    for d in data["definitions"]:
        print(f"  {d['file']}: {short(d['value'])}")


def explain(args):
    target = args.service
    if "/" not in target:
        services = ROOT / "hosts/nixos" / args.host / "services"
        candidates = [services / target, services / f"{target}.nix"]
        found = next((c for c in candidates if c.exists()), None)
        if found is None:
            sys.exit(f"no service {target!r} in {services.relative_to(ROOT)}")
        target = str(found.relative_to(ROOT))
    prefix = target.rstrip("/") + ("/" if (ROOT / target).is_dir() else "")
    data = evaluate(
        args.host,
        f"q.explain {{ inherit (system) config options; dir = {json.dumps(prefix)}; }}",
    )
    print(f"{target} on {args.host}")
    sections = [
        ("ports", lambda: [f"{n} {p}" for n, p in data["ports"].items()]),
        (
            "http",
            lambda: (
                [
                    f"{n}: {e['url']}  {e['transport']}, auth {e['authentication']}"
                    + (", monitored" if e["monitor"] else "")
                    for n, e in data["web"].items()
                ]
                + [f"{n}: {url}  static files" for n, url in data["staticWeb"].items()]
            ),
        ),
        (
            "lan",
            lambda: [
                f"{n}: {g['port']}/{','.join(g['protocols'])} on {g['interface']}"
                for n, g in data["lan"].items()
            ],
        ),
        (
            "pangolin",
            lambda: (
                [f"private {n}: {short(r)}" for n, r in data["private"].items()]
                + [
                    f"tcp {n}: {r['port']} -> public {r['publicPort']}"
                    for n, r in data["rawTcp"].items()
                ]
                + [
                    f"udp {n}: {r['port']} -> public {r['publicPort']}"
                    for n, r in data["rawUdp"].items()
                ]
            ),
        ),
        ("units", lambda: [", ".join(data["units"])] if data["units"] else []),
        ("timers", lambda: [", ".join(data["timers"])] if data["timers"] else []),
        (
            "containers",
            lambda: [f"{n}: {image}" for n, image in data["containers"].items()],
        ),
        ("secrets", lambda: [", ".join(data["secrets"])] if data["secrets"] else []),
        (
            "state",
            lambda: (
                [f"{n}: {', '.join(map(str, d))}" for n, d in data["state"].items()]
                + [
                    f"{n} (cache): {', '.join(map(str, d))}"
                    for n, d in data["cache"].items()
                ]
            ),
        ),
        (
            "offsite",
            lambda: [", ".join(map(str, data["offsite"]))] if data["offsite"] else [],
        ),
        ("files", lambda: data["files"]),
    ]
    for title, render in sections:
        lines = render()
        if lines:
            print(f"  {title}")
            for line in lines:
                print(f"    {line}")


def main():
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    sub = parser.add_subparsers(dest="command", required=True)
    w = sub.add_parser("where", help="list the files that define an option")
    w.add_argument("option")
    w.add_argument("--host", default=socket.gethostname())
    e = sub.add_parser("explain", help="show what a service contributes to a host")
    e.add_argument("service")
    e.add_argument("--host", default=socket.gethostname())
    args = parser.parse_args()
    {"where": where, "explain": explain}[args.command](args)


if __name__ == "__main__":
    main()
