#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq common-updater-scripts

set -eou pipefail

PACKAGE_PATH=./pkgs/zen-browser-unwrapped
PACKAGE_NIX="$PACKAGE_PATH"/default.nix

version="$(curl --silent 'https://api.github.com/repos/zen-browser/desktop/releases/latest' | jq --raw-output '.tag_name')"
update-source-version zen-browser-unwrapped "${version}" --file="$PACKAGE_NIX"

