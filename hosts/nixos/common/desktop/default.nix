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
    ./hyprland.nix
  ];

  config = lib.mkIf config.yomi.machine.graphical {
    stylix.targets.gtk.enable = true;

    services.upower.enable = true;

    # https://nixos.wiki/wiki/Bluetooth
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };
}
