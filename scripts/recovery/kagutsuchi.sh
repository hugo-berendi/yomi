#!/usr/bin/env bash
# Unlock and mount kagutsuchi, the USB stick holding install-time keys and the
# offline GPG and Age backups, at /kagutsuchi; or unmount and lock it again.
#
# It is LUKS2 because it holds host private keys, including the one every sops
# file is encrypted to. It used to be plain ext4, readable by whoever held it.
# The UUID is the LUKS header's, chosen at luksFormat time with --uuid.
set -euo pipefail

uuid=40ed3eaf-4232-4961-b87b-88b2f998ec10
name=kagutsuchi
mountpoint=/kagutsuchi

case "${1:-}" in
open)
	if mountpoint -q "$mountpoint"; then
		echo "📂 kagutsuchi already mounted"
		exit 0
	fi
	[ -e "/dev/mapper/$name" ] || cryptsetup open "/dev/disk/by-uuid/$uuid" "$name"
	mkdir -p "$mountpoint"
	mount "/dev/mapper/$name" "$mountpoint"
	echo "📂 kagutsuchi mounted at $mountpoint"
	;;
close)
	if mountpoint -q "$mountpoint"; then
		umount "$mountpoint"
	fi
	[ ! -e "/dev/mapper/$name" ] || cryptsetup close "$name"
	echo "🔒 kagutsuchi locked"
	;;
*)
	echo "❓ Usage: $0 open|close" >&2
	exit 1
	;;
esac
