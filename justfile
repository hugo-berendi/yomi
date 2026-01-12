[private]
default:
  @just --list

hostname := `hostname`

# {{{ Nixos rebuilds
[doc("Wrapper around `nixos-rebuild`, taking care of the generic arguments")]
[group("nix")]
nixos-rebuild action="switch" host=hostname ng="1" install_bootloader="0":
  #!/usr/bin/env python3
  import subprocess

  install_bootloader = "{{install_bootloader}}" != "0"
  ng = "{{ng}}" != "0"
  host = "{{host}}"
  users = {
    'amaterasu': 'hugob',
    'inari': 'hugob',
    'tsukuyomi': 'hugob',
    'wsl': 'hugob',
  }

  args = [
    "nixos-rebuild-ng" if ng else "nixos-rebuild",
    "{{action}}",
    "--show-trace",
    "--accept-flake-config",
    "--flake",
    ".#{{host}}",
    "--no-reexec" if ng else "--fast",
    "--install-bootloader"
  ]

  if install_bootloader:
    args.append("--install-bootloader")

  if host == "{{hostname}}":
    print("🧬 Switching nixos configuration (locally) for '{{BLUE + host + NORMAL}}'")
    args = ["sudo", *args]
  else:
    print("🧬 Switching nixos configuration (remotely) for '{{BLUE + host + NORMAL}}'")
    args += [ "--target-host", f"{users[host]}@{host}" ]
    if ng:
      args += [ "--sudo", "--ask-sudo-password" ]
    else:
      args += [ "--use-remote-sudo" ]

  try:
    subprocess.run(args, check=True)
    print("🚀 All done!")
  except KeyboardInterrupt:
    print("🪓 Command cancelled")
  except:
    print("💢 Something went wrong")
# }}}
# {{{ Miscellaneous nix commands
[doc("Build the custom ISO provided by the flake")]
[group("nix")]
build-iso:
  nix build .#nixosConfigurations.iso.config.system.build.isoImage --accept-flake-config

[doc("Bumps flake inputs that usually need to be as up to date as possible")]
[group("nix")]
bump-common:
  nix flake update \
    nixpkgs \
    nixpkgs-unstable \
    nix-index-database \
    neovim-nightly-overlay \
    firefox-addons \
    base16-schemes \
    rose-pine-hyprcursor \
    darkmatter-grub-theme \
    home-manager \
    stylix \
    nixcord \
    --accept-flake-config
# }}}

# Rebuild the system
rebuild:
	sudo nh switch .#$(hostname)

# {{{ CI/Quality checks
[doc("Run all flake checks (builds hosts, DNS, formatter)")]
[group("ci")]
check:
  nix flake check --all-systems --show-trace

[doc("Check Nix code formatting")]
[group("ci")]
format-check:
  nix fmt -- --check .

[doc("Format Nix code")]
[group("ci")]
format:
  nix fmt

[doc("Check Lua code formatting")]
[group("ci")]
format-lua-check:
  stylua --check .

[doc("Format Lua code")]
[group("ci")]
format-lua:
  stylua .

[doc("Run all formatting checks (Nix + Lua)")]
[group("ci")]
lint: format-check format-lua-check

[doc("Format all code (Nix + Lua)")]
[group("ci")]
fmt: format format-lua

[doc("Pre-commit check: format + flake check")]
[group("ci")]
pre-commit: fmt check
# }}}

# {{{ Garbage collection
[doc("Completely clean up the system by removing old generations and running garbage collection")]
[group("nix")]
gc:
  #!/usr/bin/env bash
  set -euo pipefail

  echo "🧹 Deleting old NixOS generations..."
  sudo nix-collect-garbage --delete-older-than 7d

  echo "🧹 Running garbage collection..."
  sudo nix-collect-garbage -d

  echo "🧹 Optimizing nix store..."
  sudo nix-store --optimise

  echo "🚀 All done!"
# }}}
# {{{ Age / sops related thingies
[doc("Save the user's SSH key as a key usable by sops")]
[group("secrets")]
ssh-to-age:
  @echo "📁 Creating sops directory" >&2
  mkdir -p ~/.config/sops/age

  @echo "🔑 Converting ssh key to age" >&2
  ssh-to-age -private-key -i ~/.ssh/id_ed25519 > ~/.config/sops/age/keys.txt

[doc("Print the public age key used by sops on this machine")]
[group("secrets")]
age-public-key: ssh-to-age
  @echo "🔑 Printing public age key" >&2
  age-keygen -y ~/.config/sops/age/keys.txt

[doc("Rekey every secrets file in the repository")]
[group("secrets")]
sops-rekey:
  #!/usr/bin/env python3
  import glob
  import subprocess

  paths = glob.glob("./**/secrets.yaml", recursive=True)
  for file in paths:
    print(f"🔑 Rekeying {file}")
    subprocess.run(["sops", "updatekeys", "--yes", file], check=True)

  print(f"🚀 Successfully rekeyed {len(paths)} files!")

[doc("Export keys to the kagutsuchi USB device")]
[group("secrets")]
export-keys:
  #!/usr/bin/env bash
  set -euo pipefail

  dir=/kagutsuchi/secrets/{{hostname}}/
  mkdir -p $dir

  cp /persist/state/etc/ssh/ssh* $dir
  cp /home/*/.ssh/id* $dir

  touch $dir/disk.key
  echo "💫 Don't forget to provide a disk encryption key!"
# }}}
# {{{ DNS
[doc("Prints the differences between the current and desired DNS records")]
[group("dns")]
dns-diff:
  nix run .#octodns-sync --accept-flake-config --

[doc("Syncs DNS records using octodns")]
[group("dns")]
dns-push:
  nix run .#octodns-sync --accept-flake-config -- --doit

[doc("Clears every DNS record")]
[group("dns")]
dns-clear zoneid bearerfile="/run/secrets/cloudflare_dns_api_token":
  #!/usr/bin/env python3
  import subprocess
  import requests
  import sys
  import os

  zoneid = "{{zoneid}}"
  bearerfile = "{{bearerfile}}"

  def load_bearer_token(filepath: str) -> str:
      try:
          with open(filepath, 'r') as f:
              return f.read().strip()
      except FileNotFoundError:
          print(f"❌ Bearer token file '{filepath}' not found.")
          sys.exit(1)

  def get_dns_record_ids(zone_id: str, bearer: str):
      url = f"https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records?per_page=50000"
      headers = {
          "Authorization": f"Bearer {bearer}",
          "Content-Type": "application/json"
      }
      response = requests.get(url, headers=headers)
      response.raise_for_status()
      records = response.json().get("result", [])
      return [record["id"] for record in records]

  def delete_dns_record(zone_id: str, record_id: str, bearer: str):
      url = f"https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records/{record_id}"
      headers = {
          "Authorization": f"Bearer {bearer}",
          "Content-Type": "application/json"
      }
      response = requests.delete(url, headers=headers)
      if response.ok:
          print(f"🧹 Deleted record '{record_id}'")
      else:
          print(f"⚠️ Failed to delete record '{record_id}': {response.status_code} {response.text}")

  if os.geteuid() != 0:
    os.execvp('sudo', ['sudo', 'python3'] + sys.argv)

  bearer = load_bearer_token(bearerfile)
  print(f"🔍 Fetching DNS records for zone: {zoneid}")
  try:
      record_ids = get_dns_record_ids(zoneid, bearer)
  except Exception as e:
      print(f"❌ Failed to fetch records: {e}")
      sys.exit(1)

  for record_id in record_ids:
      delete_dns_record(zoneid, record_id, bearer)

  print("🚀 All done!")
# }}}
# {{{ Security
[doc("Audit systemd service hardening using systemd-analyze security")]
[group("security")]
security-audit host=hostname services="":
  #!/usr/bin/env bash
  set -euo pipefail

  host="{{host}}"
  services="{{services}}"

  if [[ "$host" == "{{hostname}}" ]]; then
    if [[ -n "$services" ]]; then
      for svc in $services; do
        systemd-analyze security "$svc" 2>/dev/null || echo "Service $svc not found"
      done
    else
      systemd-analyze security 2>/dev/null | head -80
    fi
  else
    if [[ -n "$services" ]]; then
      for svc in $services; do
        ssh "$host" "systemd-analyze security $svc" 2>/dev/null || echo "Service $svc not found"
      done
    else
      ssh "$host" "systemd-analyze security" 2>/dev/null | head -80
    fi
  fi
# }}}
