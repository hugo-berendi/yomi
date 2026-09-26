#!/usr/bin/env bash
# Preserve recovery material before testing a restore. Never restore over live data.
set -euo pipefail
umask 077

cd "$(dirname "$(readlink -f "$0")")/.."
[[ $(hostname) == inari ]] || {
	echo 'Run this on Inari.' >&2
	exit 1
}
if ((EUID != 0)); then
	restic="$(nix eval --raw '.#nixosConfigurations.inari.config.services.restic.backups.data.package.outPath')/bin/restic"
	exec /run/wrappers/bin/sudo bash "$PWD/scripts/inari-migration-check.sh" \
		"$(command -v age)" "$(command -v ssh-to-age)" "$(command -v jq)" "$restic" \
		"$(nix build --no-link --print-out-paths '.#nixosConfigurations.inari.pkgs.age-plugin-yubikey')/bin"
fi
[[ $# == 5 ]] || {
	echo 'Start with: nix develop -c bash scripts/inari-migration-check.sh' >&2
	exit 1
}
age=$1
ssh_to_age=$2
jq=$3
restic=$4
# age calls age-plugin-yubikey from PATH to encrypt to the PIV recipient.
export PATH="$5:$PATH"
for tool in "$age" "$ssh_to_age" "$jq" "$restic"; do test -x "$tool"; done
[[ $(findmnt -n -o SOURCE -T /raid5pool/backups) == raid5pool/backups ]]
for file in /boot/zroot-key.jwe /boot/zroot-recovery-key.age \
	/persist/state/etc/ssh/ssh_host_ed25519_key /run/secrets/backup_password \
	/run/secrets/rendered/restic-b2.env /run/secrets/rendered/restic-b2-repository; do
	test -s "$file"
done

# Separate directories make an interrupted run safe to repeat and retain its evidence.
work=$(mktemp -d /raid5pool/backups/inari-migration.XXXXXXXX)
scratch=$(mktemp -d /run/inari-migration.XXXXXXXX)
trap 'rm -rf -- "$scratch"' EXIT
exec > >(tee "$work/report.txt") 2>&1
echo "Recovery audit: $work"
date --iso-8601=seconds
git rev-parse HEAD
readlink -f /run/current-system
lsblk -d -o NAME,SIZE,MODEL,SERIAL
zpool status -P
zpool get guid,compatibility raid5pool
zfs get -t filesystem -r encryption,keylocation,keystatus,mountpoint raid5pool zroot

# Encrypt to every recipient in .sops.yaml, so the archive opens with whatever
# opens the secrets: the offline key on kagutsuchi and the YubiKey's PIV identity
# as well as the old keys, which are retired after this migration.
mapfile -t recipients < <(awk '$1 == "-" && $2 ~ /^&/ {print "-r"; print $3}' .sops.yaml)
((${#recipients[@]} > 0))
printf '%s\n' "${recipients[@]}" | grep -v '^-r$'

# Encrypt before writing to the unencrypted HDD pool. Include the checkout because
# the regular local backup excludes projects and .git. Never log credential values.
tar -C / -chf - boot persist/state/etc/ssh persist/state/etc/secrets/initrd \
	run/secrets/backup_password run/secrets/rendered/restic-b2.env \
	run/secrets/rendered/restic-b2-repository \
	-C "$PWD" . |
	"$age" "${recipients[@]}" -o "$work/recovery.tar.age"
"$ssh_to_age" -private-key -i /persist/state/etc/ssh/ssh_host_ed25519_key -o "$scratch/identity"
"$age" -d -i "$scratch/identity" "$work/recovery.tar.age" | tar -tf - >/dev/null
"$age" -d -i "$scratch/identity" "$work/recovery.tar.age" |
	tar -xOf - run/secrets/backup_password >"$scratch/backup_password"
cmp -s "$scratch/backup_password" /run/secrets/backup_password
"$age" -d -i "$scratch/identity" /boot/zroot-recovery-key.age >"$scratch/zroot-key"
zfs load-key -n -L "file://$scratch/zroot-key" zroot
sha256sum "$work/recovery.tar.age"
echo 'Recovery archive decrypts locally; the ZFS recovery key validates. An independent-machine decryption test is still required.'

# Use the password recovered from the archive, not the live /run/secrets file.
unset RESTIC_REPOSITORY RESTIC_REPOSITORY_FILE RESTIC_PASSWORD RESTIC_PASSWORD_COMMAND
export RESTIC_PASSWORD_FILE="$scratch/backup_password"
export RESTIC_CACHE_DIR="$work/cache"
for set in data state; do
	repository="/raid5pool/backups/restic/$set"
	"$restic" -r "$repository" --retry-lock=2m snapshots --host inari --json >"$work/$set-snapshots.json"
	"$jq" -r '.[] | [.id, .time, (.paths | join(","))] | @tsv' "$work/$set-snapshots.json"
	# shellcheck disable=SC2016 # $path is a jq variable.
	snapshot=$("$jq" -er --arg path "/persist/$set" \
		'[.[] | select(.paths == [$path])] | max_by(.time).id // error("No matching snapshot")' "$work/$set-snapshots.json")
	# Reserve generous space for the observed ~191 GiB restore. Recheck per set.
	available=$(df -B1 --output=avail "$work" | tail -n 1)
	((available > 300 * 1024 * 1024 * 1024)) || {
		echo 'Less than 300 GiB free; stopping.'
		exit 1
	}
	echo "Restoring $set snapshot $snapshot into $work/restore-$set"
	"$restic" -r "$repository" --retry-lock=2m check
	"$restic" -r "$repository" --retry-lock=2m restore "$snapshot" --target "$work/restore-$set" --verify
done
echo 'PASS: both selected local snapshots restored and verified. This does not prove application/database consistency or freshness.'
echo "Keep $work private. Copy recovery.tar.age to another device and test decryption there before returning the SSD."
