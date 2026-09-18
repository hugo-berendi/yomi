[private]
default:
  @just --list

hostname := `hostname`

# {{{ Nixos rebuilds
[doc("Wrapper around `nixos-rebuild`, taking care of the generic arguments")]
[group("nix")]
nixos-rebuild action="switch" host=hostname install_bootloader="0":
  #!/usr/bin/env python3
  import os
  import subprocess
  import sys

  install_bootloader = "{{install_bootloader}}" != "0"
  host = "{{host}}"
  users = {
    'amaterasu': 'hugob',
    'inari': 'hugob',
    'tsukuyomi': 'hugob',
    'wsl': 'hugob',
  }

  args = [
    "nixos-rebuild",
    "{{action}}",
    "--show-trace",
    "--accept-flake-config",
    "--flake",
    ".#{{host}}",
    "--no-reexec",
  ]

  if install_bootloader:
    args.append("--install-bootloader")

  if host == "{{hostname}}" or "{{action}}" in {"build", "dry-build"}:
    print("🧬 Switching nixos configuration (locally) for '{{BLUE + host + NORMAL}}'")
    if host == "{{hostname}}" and "{{action}}" in {"switch", "boot", "test", "dry-activate"}:
      sudo_bin = "/run/wrappers/bin/sudo" if os.path.exists("/run/wrappers/bin/sudo") else "sudo"
      args = [sudo_bin, *args]
  else:
    print("🧬 Switching nixos configuration (remotely) for '{{BLUE + host + NORMAL}}'")
    args += ["--target-host", f"{users[host]}@{host}", "--sudo"]

  if not sys.stdout.isatty():
    args += ["--log-format", "raw"]

  try:
    subprocess.run(args, check=True)
    print("🚀 All done!")
  except KeyboardInterrupt:
    print("🪓 Command cancelled")
    sys.exit(130)
  except subprocess.CalledProcessError as error:
    print("💢 Something went wrong")
    sys.exit(error.returncode)
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
    rose-pine-hyprcursor \
    home-manager \
    stylix \
    nixcord \
    skills \
    --accept-flake-config
# }}}

# Rebuild the system
rebuild:
	sudo nh switch .#$(hostname)

# {{{ CI/Quality checks
[doc("Run all flake checks (builds hosts, DNS, formatter)")]
[group("ci")]
check:
  nix flake check --show-trace --keep-going

[doc("Check Nix code formatting")]
[group("ci")]
format-check:
  nix fmt -- --check .

[doc("Format Nix code")]
[group("ci")]
format:
  nix fmt -- .

[doc("Check Lua code formatting")]
[group("ci")]
format-lua-check:
  stylua --check .

[doc("Format Lua code")]
[group("ci")]
format-lua:
  stylua .

[doc("Check for Nix anti-patterns using statix")]
[group("ci")]
statix-check:
  nix develop -c statix check .

[doc("Check for unused Nix bindings using deadnix")]
[group("ci")]
deadnix-check:
  nix develop -c deadnix --fail .

[doc("Check Python source with Ruff")]
[group("ci")]
python-check:
  nix develop -c ruff check .
  nix develop -c ruff format --check .

[doc("Check shell scripts with ShellCheck and shfmt")]
[group("ci")]
shell-check:
  git ls-files -z '*.sh' | xargs -0 nix develop -c shellcheck --shell=bash
  git ls-files -z '*.sh' | xargs -0 nix develop -c shfmt -d

[doc("Run all formatting checks (Nix + Lua + linters)")]
[group("ci")]
lint: format-check format-lua-check statix-check deadnix-check python-check shell-check

[doc("Format all code (Nix + Lua)")]
[group("ci")]
fmt: format format-lua

[doc("Pre-commit check: format + flake check")]
[group("ci")]
pre-commit: fmt check

[doc("Push wsl build to hugo-berendi cachix cache")]
[group("ci")]
push-wsl-cache:
  nix build .#nixosConfigurations.wsl.config.system.build.toplevel --accept-flake-config
  nix copy --to ssh://hugo-berendi.cachix.org .#nixosConfigurations.wsl.config.system.build.toplevel
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
  #!/usr/bin/env bash
  set -euo pipefail

  dest=~/.config/sops/age/keys.txt

  echo "📁 Creating sops directory" >&2
  mkdir -p ~/.config/sops/age

  # The pilot's ssh key is passphrase-protected, and ssh-to-age has no flag for
  # that -- it reads SSH_TO_AGE_PASSPHRASE from the environment. Writing
  # straight to $dest with `>` truncated it before the conversion could fail,
  # which destroyed a working key file on every unattended run.
  echo "🔑 Converting ssh key to age" >&2
  tmp=$(mktemp)
  chmod 600 "$tmp"
  trap 'rm -f "$tmp"' EXIT

  if ! ssh-to-age -private-key -i ~/.ssh/id_ed25519 -o "$tmp" || [[ ! -s "$tmp" ]]; then
    echo "❌ Conversion failed and $dest was left untouched." >&2
    echo "   The key is passphrase-protected; retry with:" >&2
    echo "     SSH_TO_AGE_PASSPHRASE=... just ssh-to-age" >&2
    exit 1
  fi

  install -m 600 "$tmp" "$dest"
  echo "🚀 Wrote $dest" >&2

[doc("Print the public age key used by sops on this machine")]
[group("secrets")]
age-public-key: ssh-to-age
  @echo "🔑 Printing public age key" >&2
  age-keygen -y ~/.config/sops/age/keys.txt

[doc("Export n8n's live workflows back into the repository")]
[group("nix")]
n8n-export:
  #!/usr/bin/env bash
  set -euo pipefail

  dir="hosts/nixos/inari/services/n8n/workflows"
  sudo_bin="/run/wrappers/bin/sudo"

  # n8n runs DynamicUser, so its uid does not exist outside the unit and
  # `sudo -u` cannot reach the database. Root can, via the real state path
  # behind StateDirectory.
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT

  echo "📤 Exporting workflows from n8n"
  "$sudo_bin" env \
    N8N_USER_FOLDER=/var/lib/private/n8n \
    HOME=/var/lib/private/n8n \
    n8n export:workflow --all --separate --output="$tmp"

  # jq -S so re-exports produce stable diffs, and drop meta.instanceId: it
  # fingerprints this n8n install and does not belong in a mirrored repo.
  mkdir -p "$dir"
  for f in "$tmp"/*.json; do
    name=$(jq -r '.name' "$f" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9-')
    "$sudo_bin" cat "$f" | jq -S 'del(.meta)' > "$dir/$name.json"
    echo "  $dir/$name.json"
  done

  echo "🚀 Exported $(ls -1 "$dir"/*.json | wc -l) workflow(s). Review the diff before committing."

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

[doc("Copy a running host's real ssh host public key into the repo, so knownHosts can pin it")]
[group("secrets")]
import-host-key host:
  #!/usr/bin/env bash
  set -euo pipefail

  host="{{host}}"
  dest="hosts/nixos/$host/keys/ssh_host_ed25519_key.pub"
  idkey="hosts/nixos/$host/keys/id_ed25519.pub"

  if [[ ! -d "hosts/nixos/$host" ]]; then
    echo "❌ No such host in this repo: $host" >&2
    exit 1
  fi

  echo "🔑 Fetching the host key from $host"
  mkdir -p "$(dirname "$dest")"
  tmp=$(mktemp)
  trap 'rm -f "$tmp"' EXIT
  ssh "$host" 'cat /persist/state/etc/ssh/ssh_host_ed25519_key.pub 2>/dev/null || cat /etc/ssh/ssh_host_ed25519_key.pub' > "$tmp"

  if ! grep -q '^ssh-ed25519 ' "$tmp"; then
    echo "❌ That does not look like an ed25519 public key, refusing to write it" >&2
    exit 1
  fi

  # This is the mistake that left both desktops pinned to an unusable key for
  # two years: the pilot's user key was copied in here instead of the host key.
  if [[ -f "$idkey" ]] && [[ "$(cut -d' ' -f2 "$tmp")" == "$(cut -d' ' -f2 "$idkey")" ]]; then
    echo "❌ $host is presenting the pilot's user key as its host key." >&2
    echo "   Pinning it would be meaningless. Regenerate the host key instead." >&2
    exit 1
  fi

  # install rather than mv: mktemp makes the file 0600, and this is a public key.
  install -m 644 "$tmp" "$dest"
  git add "$dest"
  echo "🚀 Pinned $(cut -d' ' -f3 "$dest" 2>/dev/null || echo "$host") in $dest"

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
    sudo_bin = "/run/wrappers/bin/sudo" if os.path.exists("/run/wrappers/bin/sudo") else "sudo"
    os.execvp(sudo_bin, [sudo_bin, 'python3'] + sys.argv)

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
