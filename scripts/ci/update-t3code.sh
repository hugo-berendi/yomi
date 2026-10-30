#!/usr/bin/env bash
# Bump t3code to the latest stable release.
#
# Three files move together: pkgs/t3code-release.nix (the release tarball),
# pkgs/t3code-memory.nix (the memory server, built from source with our patch;
# the release build asserts the two versions match) and
# pkgs/patches/t3code/shared-memory.patch, which has to be rebased onto every
# new tag. Git's 3-way merge does the rebase. If it conflicts, or anything fails
# to build, the three paths are restored and the script exits non-zero, so the
# job carries on without a t3code change and a human rebases the patch.
#
# A changed patch is not a hash or version bump, so update-gate.py refuses it
# and the PR waits for review. A bump that leaves the patch byte-identical
# passes the gate like any other package update.
set -euo pipefail

repo=https://github.com/pingdotgg/t3code
release=pkgs/t3code-release.nix
memory=pkgs/t3code-memory.nix
patch=pkgs/patches/t3code/shared-memory.patch
fake=sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=

current=$(sed -n 's/^  version = "\(.*\)";$/\1/p' "$release" | head -1)
# An explicit version (first argument) replaces the lookup, for a manual bump or a test.
# Otherwise stable tags only: nightly and preview tags have a suffix after the patch number.
latest=${1:-$(git ls-remote --tags --refs "$repo" 'v*' |
	sed -n 's|.*refs/tags/v\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\)$|\1|p' |
	sort -V | tail -1)}

if [[ -z $latest ]]; then
	echo "no stable t3code tag found" >&2
	exit 1
fi
if [[ $latest == "$current" || $(printf '%s\n%s\n' "$current" "$latest" | sort -V | tail -1) != "$latest" ]]; then
	echo "t3code $current is up to date (latest stable: $latest)"
	exit 0
fi
echo "t3code $current -> $latest"

work=$(mktemp -d)
# Any exit that is not a finished update, including a failing command under set -e,
# puts the three files back.
succeeded=false
finish() {
	rm -rf "$work"
	$succeeded || git checkout -- "$release" "$memory" "$patch"
}
trap finish EXIT
fail() {
	echo "::warning::t3code $latest: $1; left at $current" >&2
	exit 1
}

new_rev=$(git ls-remote --tags "$repo" "refs/tags/v$latest" | cut -f1)
old_rev=$(sed -n 's/^    rev = "\(.*\)";$/\1/p' "$memory")

# Rebase the patch: replay it on the old tag, then cherry-pick that commit onto the new one.
timeout 900 git clone --quiet "$repo" "$work/src" || fail "could not clone $repo"
git_in() { git -C "$work/src" -c user.name=ci -c user.email=ci@localhost "$@"; }
git_in checkout --quiet --force "$old_rev"
git_in apply --index "$PWD/$patch"
git_in commit --quiet -m "shared memory"
patch_commit=$(git_in rev-parse HEAD)
git_in checkout --quiet --force "$new_rev"
git_in cherry-pick --no-commit "$patch_commit" >/dev/null 2>&1 || fail "the shared-memory patch no longer merges cleanly"
git_in diff --cached "$new_rev" >"$work/new.patch"
cp "$work/new.patch" "$patch"

# Hashes. nix prints the correct pnpm dependency hash when given a wrong one.
hash_of() { sed -n 's/.*"hash": *"\([^"]*\)".*/\1/p'; }
tarball_hash=$(nix store prefetch-file --json "$repo/releases/download/v$latest/t3-$latest-linux-x64.tar.gz" | hash_of)
src_hash=$(nix store prefetch-file --json --unpack "$repo/archive/$new_rev.tar.gz" | hash_of)
old_tarball_hash=$(sed -n 's/^        hash = "\(.*\)";$/\1/p' "$release")
old_src_hash=$(sed -n '/= fetchFromGitHub {/,/};/s/^    hash = "\(.*\)";$/\1/p' "$memory")
old_deps_hash=$(sed -n '/= fetchPnpmDeps {/,/};/s/^    hash = "\(.*\)";$/\1/p' "$memory")
[[ -n $tarball_hash && -n $src_hash && -n $old_tarball_hash && -n $old_src_hash && -n $old_deps_hash ]] ||
	fail "could not read or compute a hash"

sed -i "s|version = \"$current\";|version = \"$latest\";|; s|$old_tarball_hash|$tarball_hash|" "$release"
sed -i "s|version = \"$current\";|version = \"$latest\";|; s|$old_rev|$new_rev|; s|$old_src_hash|$src_hash|; s|$old_deps_hash|$fake|" "$memory"

expr_for() {
	printf 'let f = builtins.getFlake (toString ./.); pkgs = f.nixosConfigurations.inari.pkgs; memory = pkgs.callPackage ./pkgs/t3code-memory.nix {}; in %s' "$1"
}
deps_log=$(nix build --no-link --accept-flake-config --impure --expr "$(expr_for memory.pnpmDeps)" 2>&1 || true)
deps_hash=$(sed -n 's/^ *got: *\(sha256-[A-Za-z0-9+\/]*=*\)$/\1/p' <<<"$deps_log" | head -1)
[[ -n $deps_hash ]] || fail "could not determine the pnpm dependency hash"
sed -i "s|$fake|$deps_hash|" "$memory"

nix build --no-link --accept-flake-config --impure \
	--expr "$(expr_for 'pkgs.callPackage ./pkgs/t3code-release.nix { memoryServer = memory; }')" ||
	fail "the release does not build"
succeeded=true
echo "t3code updated to $latest"
