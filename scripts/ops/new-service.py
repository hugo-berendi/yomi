"""Start a new service on a host: one file, a free port, and the usual blocks.

    new-service.py NAME [--host HOST]

Writes hosts/nixos/HOST/services/NAME.nix, picks the lowest port from 8401
that no yomi.ports entry on the host uses, and stages the file so the flake
sees it. The file is a starting point: fill in the service, choose the
transport and authentication, then check it with `just explain NAME`.
"""

import argparse
import json
import pathlib
import re
import socket
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]

TEMPLATE = """\
# {name}: TODO one line on what this is and who uses it.
{{config, ...}}: let
  port = config.yomi.ports.{name};
in {{
  # {{{{{{ Ports and reachability
  yomi.ports.{name} = {port};
  yomi.web.at.{name} = {{
    inherit port;
    # nginx: LAN only. pangolin: also reachable from outside, through ebisu.
    transport = "nginx";
    # Who checks requests: application, gateway (Pangolin SSO) or none.
    authentication = "application";
    monitor.enable = true;
  }};
  # }}}}}}
  # {{{{{{ Service
  services.{name} = {{
    enable = true;
  }};
  # }}}}}}
  # {{{{{{ State
  # Anything not listed here is erased on boot (impermanence).
  yomi.persistence.at.state.apps.{name}.directories = ["/var/lib/{name}"];
  # }}}}}}
  # Hardening: run `just hardening-report` first. Upstream modules often
  # sandbox already; add only what this service lacks, in
  # systemd.services.<unit>.serviceConfig.
}}
"""


def main():
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("name")
    parser.add_argument("--host", default=socket.gethostname())
    args = parser.parse_args()

    if not re.fullmatch(r"[a-z][a-z0-9-]*", args.name):
        sys.exit("use a lowercase name with dashes, like the unit it configures")
    services = ROOT / "hosts/nixos" / args.host / "services"
    target = services / f"{args.name}.nix"
    if target.exists() or (services / args.name).exists():
        sys.exit(f"{target.relative_to(ROOT)} already exists")
    if not services.is_dir():
        sys.exit(
            f"{services.relative_to(ROOT)} does not exist; services are auto-imported only there"
        )

    attr = f"git+file://{ROOT}#nixosConfigurations.{args.host}.config.yomi.ports"
    used = set(
        json.loads(
            subprocess.run(
                ["nix", "eval", "--json", attr],
                capture_output=True,
                text=True,
                check=True,
            ).stdout
        ).values()
    )
    port = next(p for p in range(8401, 9000) if p not in used)

    target.write_text(TEMPLATE.format(name=args.name, port=port))
    subprocess.run(["git", "add", str(target)], check=True, cwd=ROOT)
    print(f"wrote {target.relative_to(ROOT)} with port {port}")
    print(
        f"next: fill it in, then `just explain {args.name} {args.host}` and `just nixos-rebuild dry-build {args.host}`"
    )


if __name__ == "__main__":
    main()
