#!/usr/bin/env bash
# Run on the protected publisher, with a clean checkout of the approved commit.
# The build worker must already have uploaded the approved closure to the cache.
set -euo pipefail
umask 077

if (($# != 5)); then
	echo "Usage: $0 APPROVED_COMMIT SEQUENCE HTTPS_CACHE SIGNING_KEY OUTPUT_DIR" >&2
	exit 2
fi
commit=$1
sequence=$2
cache=$3
key=$4
output=$5

[[ $commit =~ ^[0-9a-f]{40}$ && $sequence =~ ^[1-9][0-9]{0,14}$ && $cache == https://* ]] || {
	echo "Expected a full Git hash, positive sequence and HTTPS cache" >&2
	exit 2
}
if [[ $(git rev-parse HEAD) != "$commit" || -n $(git status --porcelain) ]]; then
	echo "Publisher checkout must be clean and match the approved commit" >&2
	exit 2
fi
if [[ -e $output || -L $output ]]; then
	echo "Release output already exists: $output" >&2
	exit 2
fi

toplevel=$(nix eval --no-write-lock-file --raw .#nixosConfigurations.inari.config.system.build.toplevel.outPath)
[[ $toplevel =~ ^/nix/store/[0123456789abcdfghijklmnpqrsvwxyz]{32}-nixos-system-inari-[0-9A-Za-z._+-]+$ ]]
# Compare metadata for the exact checked closure. A publication must already
# exist in the cache so Inari never has to build as a fallback.
remote_info=$(nix path-info --store "$cache" --json "$toplevel")
remote_hash=$(jq -er 'if type == "array" then .[0].narHash else to_entries[0].value.narHash end' <<<"$remote_info")
nar_hash=$(nix-store --query --hash "$toplevel")
[[ $nar_hash =~ ^sha256:[0123456789abcdfghijklmnpqrsvwxyz]{52}$ ]]
[[ $(nix hash convert --hash-algo sha256 --to sri "$nar_hash") == "$remote_hash" ]]

temporary=$(mktemp -d -- "${output}.partial.XXXXXXXX")
trap 'rm -rf -- "$temporary"' EXIT
issued=$(date +%s)
jq -n --arg commit "$commit" --arg toplevel "$toplevel" --arg hash "$nar_hash" \
	--argjson sequence "$sequence" --argjson issued "$issued" \
	'{format:1,host:"inari",commit:$commit,toplevel:$toplevel,narHash:$hash,
	  sequence:$sequence,issuedAt:$issued,expiresAt:($issued + 1209600)}' >"$temporary/release.json"
ssh-keygen -Y sign -f "$key" -n yomi-release "$temporary/release.json"
mv -T --no-clobber -- "$temporary" "$output"
[[ ! -d $temporary ]]
