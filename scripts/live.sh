#!/usr/bin/env nix-shell
#!nix-shell ../devshells/bootstrap/shell.nix
#!nix-shell -i bash

set -euo pipefail

if (($# != 2 && $# != 3)); then
	echo "❓ Usage: $0 <host> <disko-mode> [action]"
	exit 1
fi

host=$1
mode=$2
action=${3:-}

if [ "$mode" != "disko" ] && [ "$mode" != "mount" ]; then
	echo "❓ Disko action must be either 'disko' or 'mount'"
	exit 1
fi

if (($# == 3)) && [ "$action" != "install" ] && [ "$action" != "enter" ]; then
	echo "❓ Action must be omitted, 'install' or 'enter'"
	exit 1
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd -- "$script_dir/.."
host_dir="hosts/nixos/$host"
if [[ ! $host =~ ^[a-zA-Z0-9_-]+$ ]] ||
	[[ ! -f "$host_dir/filesystems/partitions.nix" || ! -d "$host_dir/hardware" ]]; then
	echo "❓ No installable disk configuration for host: $host" >&2
	exit 1
fi

# Resolve every locked input before Disko can erase anything. A cold installer
# must have SSH access to the private skills input, not just a warm Nix store.
nix flake archive --no-write-lock-file --accept-flake-config >/dev/null

opened_keys=0
hardware_tmp=""
cleanup() {
	status=$?
	trap - EXIT
	if [[ -n $hardware_tmp ]]; then
		rm -f -- "$hardware_tmp"
	fi
	if ((opened_keys)); then
		"$script_dir/kagutsuchi.sh" close || {
			close_status=$?
			((status != 0)) || status=$close_status
		}
	fi
	if ((status == 0)); then
		echo "🚀 All done!"
	fi
	exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Leave an already-mounted key device alone. Claim cleanup before opening so
# a failed mount after successful LUKS unlock is also unwound.
if ! mountpoint -q /kagutsuchi; then
	opened_keys=1
fi
echo "📁 Mounting keys"
"$script_dir/kagutsuchi.sh" open

if [ "$mode" = "mount" ] && [ "$host" = "inari" ]; then
	echo "🏊 Importing zpool"
	zpool import -lfR /mnt zroot
fi

echo "💣 Running disko"
nix run --inputs-from . --accept-flake-config disko -- --mode "$mode" "$host_dir/filesystems/partitions.nix"

if [ "$action" = "install" ]; then
	echo "🛠️ Generating hardware config"
	# Keep the previous file if generation fails or produces an empty result.
	hardware_file="$host_dir/hardware/generated.nix"
	hardware_tmp=$(mktemp "$hardware_file.XXXXXXXX")
	nixos-generate-config --root /mnt --no-filesystems --show-hardware-config >"$hardware_tmp"
	test -s "$hardware_tmp"
	chmod 0644 "$hardware_tmp"
	mv -- "$hardware_tmp" "$hardware_file"
	hardware_tmp=""
	git add -- "$hardware_file"

	echo "Installing nixos"
	# --accept-flake-config: the installer environment has no yomi nix.conf yet, so
	# the flake's own nixConfig is the only source of the binary caches here.
	nixos-install --flake ".#$host" --accept-flake-config

	echo "🔑 Copying user ssh keys"
	mkdir -p /mnt/persist/state/home/hugob
	for dir in /mnt/persist/state/home/*; do
		mkdir -p "$dir/ssh/.ssh"
		cp "/kagutsuchi/secrets/$host"/id* "$dir/ssh/.ssh"
	done

	echo "🔑 Copying host ssh keys"
	mkdir -p /mnt/persist/state/etc/ssh/
	cp "/kagutsuchi/secrets/$host"/ssh* /mnt/persist/state/etc/ssh/
fi

if [ "$action" = "enter" ]; then
	echo "❄️ Entering nixos"
	nixos-enter --root /mnt
fi
