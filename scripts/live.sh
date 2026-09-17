#!/usr/bin/env nix-shell
#!nix-shell ../devshells/bootstrap/shell.nix
#!nix-shell -i bash

# Check if at least one argument is provided
if [ "$#" != "2" ] && [ "$#" != "3" ]; then
	echo "❓ Usage: $0 <host> <disko-mode> [action]"
	exit 1
fi

host=$1
mode=$2
action=${3:-}

# Ensure correct first argument type
if [ "$mode" != "disko" ] && [ "$mode" != "mount" ]; then
	echo "❓ Disko action must be either 'disko' or 'mount'"
	exit 1
fi

# Ensure correct second argument type
if [ "$#" != "2" ] && [ "$action" != "install" ] && [ "$action" != "enter" ]; then
	echo "❓ Action must either be empty, 'install' or 'enter'"
	exit 1
fi

if mountpoint -q /kagutsuchi; then
	echo "📂 Keys already mounted"
else
	echo "📁 Mounting keys"
	mkdir -p /kagutsuchi
	mount /dev/disk/by-uuid/9e2345c6-7c31-4a76-97d8-73adc71c1a19 /kagutsuchi
fi

if [ "$mode" = "mount" ] && [ "$host" = "inari" ]; then
	echo "🏊 Importing zpool"
	zpool import -lfR /mnt zroot
fi

echo "💣 Running disko"
nix run disko -- --mode "$mode" "./hosts/nixos/$host/filesystems/partitions.nix"

if [ "$action" = "install" ]; then
	echo "🛠️ Generating hardware config"
	nixos-generate-config --no-filesystems --show-hardware-config \
		>"./hosts/nixos/$host/hardware/generated.nix"
	git add .

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

echo "🚀 All done!"
