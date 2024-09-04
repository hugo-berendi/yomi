#!/usr/bin/env bash
#
# I believe there are a few ways to do this:
#
#    1. My current way, using a minimal /etc/nixos/configuration.nix that just imports my config from my home directory (see it in the gist)
#    2. Symlinking to your own configuration.nix in your home directory (I think I tried and abandoned this and links made relative paths weird)
#    3. My new favourite way: as @clot27 says, you can provide nixos-rebuild with a path to the config, allowing it to be entirely inside your dotfies, with zero bootstrapping of files required.
#       `nixos-rebuild switch -I nixos-config=path/to/configuration.nix`
#    4. If you uses a flake as your primary config, you can specify a path to `configuration.nix` in it and then `nixos-rebuild switch —flake` path/to/directory
# As I hope was clear from the video, I am new to nixos, and there may be other, better, options, in which case I'd love to know them! (I'll update the gist if so)

# A rebuild script that commits on a successful build
set -e

# cd to your config dir
pushd ~/projects/nix-config/

# Edit your config
# nvim .

# Early return if no changes were detected (thanks @singiamtel!)
if sudo git diff --quiet HEAD -- .; then
	echo "No changes detected, exiting."
	popd
	exit 0
fi

# Autoformat your nix files
alejandra . &>/dev/null ||
	(
		alejandra .
		echo "formatting failed!" && exit 1
	)

# add all changes for commit
sudo git add .

# Shows your changes
sudo git diff -U0

echo "NixOS Rebuilding..."
notify-send -e "NixOS Rebuilding..." --icon=software-update-available

# Rebuild, output simplified errors, log trackebacks
# sudo nixos-rebuild switch --upgrade-all --flake ".#${HOSTNAME}" &>nixos-switch.log || (cat nixos-switch.log | grep --color error && git reset && exit 1)
nh os switch -- --accept-flake-config
# sudo nixos-rebuild switch --flake .#$(hostname) --show-trace --fast --upgrade-all

# Rebuild home-manager, output simplified errors, log trackebacks
# home-manager switch --impure -b backup --flake ".#hugob@amaterasu" &>home-manager-switch.log || (cat home-manager-switch.log | grep --color error && git reset && exit 1)

# Init ags types
# ags --init -c /home/hugob/projects/nix-config/home/features/wayland/ags/config &>/dev/null

# Get current generation metadata
current=$(nixos-rebuild list-generations | grep current)

# Commit all changes witih the generation metadata
sudo git commit -m "$current"

# Back to where you were
popd

# Notify all OK!
notify-send -e "NixOS Rebuilt OK!" --icon=software-update-available
