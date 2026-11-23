# What every home-fleet host (amaterasu, inari, iso and the WSL hosts) shares
# on top of ./base.nix: theming, the pilot's user and secrets, the 1Password
# CLI and the beszel agent. The role profiles beside this file add the rest;
# a VPS takes ./base.nix alone.
{
  inputs,
  lib,
  config,
  ...
}: {
  # {{{ Imports
  imports = [
    # ../common/themes sets stylix options.
    inputs.stylix.nixosModules.stylix
    ../common

    ../hosts/nixos/common/cli/1password.nix
    ./users/pilot.nix
    ./services/beszel-agent.nix
  ];
  # }}}

  # Customize tty colors
  stylix.targets.console.enable = lib.mkIf config.yomi.machine.interactible true;
}
