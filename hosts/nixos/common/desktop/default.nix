{
  config,
  lib,
  ...
}: {
  imports = [
    ./pipewire.nix
    ./xdg-portal.nix
    ./steam.nix
    ./unicode.nix
    ./quietboot.nix
    ./hyperland.nix
  ];

  config = lib.mkIf config.yomi.machine.graphical {
    stylix.targets.gtk.enable = true;

    # https://nixos.wiki/wiki/Bluetooth
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };
}
