# What the home fleet (amaterasu, inari, iso and the WSL hosts) shares on top
# of ../base.nix: theming, desktop, the pilot's user and secrets, monitoring and
# the opt-in service integrations. A VPS takes ../base.nix alone.
{
  inputs,
  lib,
  config,
  ...
}: {
  # {{{ Imports
  imports = [
    inputs.stylix.nixosModules.stylix
    inputs.nix-flatpak.nixosModules.nix-flatpak
    inputs.nixarr.nixosModules.default

    ../../../../common

    ../cli/1password.nix
    ../desktop
    ../users/pilot.nix

    # services
    ../services/beszel-agent.nix
    ../services/greetd
    ../services/oci.nix
    ../services/syncthing.nix
    ../services/restic.nix
  ];
  # }}}

  yomi.wireless.sopsFile = ../secrets.yaml;

  yomi.acme = {
    sopsFile = ../secrets.yaml;
    email = "acme@hugo-berendi.de";
  };

  # Customize tty colors
  stylix.targets.console.enable = lib.mkIf config.yomi.machine.interactible true;
}
