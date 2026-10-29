#!/usr/bin/env bash
# What `nix flake check` does, one flake output per nix process.
#
# A single `nix flake check` of all five hosts plus every package held 8.3 GB
# resident in the evaluator for most of an hour on inari, where it ran at the
# CI runner's 8 GB MemoryHigh and was throttled the whole time. Evaluator
# memory is only returned when the process exits, so each output gets its own
# process and the peak is one host, not their sum.
#
# Mirrors flake check: build every `checks` entry, evaluate the derivations of
# the other outputs without building them. Like --keep-going, it runs all of
# them and reports every failure at the end.
set -euo pipefail

system=x86_64-linux
flake=${1:-.}
failed=()

names() {
	nix eval --accept-flake-config --raw "$flake#$1" \
		--apply 'x: builtins.concatStringsSep "\n" (builtins.attrNames x) + "\n"'
}

run() {
	local label=$1
	shift
	echo "::group::$label"
	if ! "$@"; then
		failed+=("$label")
	fi
	echo "::endgroup::"
}

while read -r name; do
	run "checks.$name" nix build --accept-flake-config --show-trace --no-link "$flake#checks.$system.$name"
done < <(names "checks.$system")

for output in packages devShells; do
	while read -r name; do
		run "$output.$name" nix eval --accept-flake-config --show-trace --raw "$flake#$output.$system.$name.drvPath"
	done < <(names "$output.$system")
done

run "formatter" nix eval --accept-flake-config --show-trace --raw "$flake#formatter.$system.drvPath"

if ((${#failed[@]})); then
	printf 'FAILED: %s\n' "${failed[@]}" >&2
	exit 1
fi
