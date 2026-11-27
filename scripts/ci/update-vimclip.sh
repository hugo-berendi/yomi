#!/usr/bin/env bash
set -euo pipefail

# GitHub's commits Atom feed can return 504 while the API remains available.
commit=$(curl --fail --silent --show-error --retry 3 \
	https://api.github.com/repos/hrantzsch/vimclip/commits/master)
rev=$(jq -er '.sha | select(test("^[0-9a-f]{40}$"))' <<<"$commit")
date=$(jq -er '.commit.committer.date | capture("^(?<date>[0-9]{4}-[0-9]{2}-[0-9]{2})T").date' <<<"$commit")
hash=$(nix-prefetch-url --unpack "https://github.com/hrantzsch/vimclip/archive/$rev.tar.gz")
hash=$(nix hash to-sri --type sha256 "$hash")
sed -i \
	-e "s|version = \".*\";|version = \"1.0.0-unstable-$date\";|" \
	-e "s|rev = \".*\";|rev = \"$rev\";|" \
	-e "s|hash = \".*\";|hash = \"$hash\";|" \
	pkgs/vimclip.nix
