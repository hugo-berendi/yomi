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
    ./helium.nix
  ];

  config = lib.mkMerge [
    (lib.mkIf config.yomi.machine.graphical {
      stylix.targets.gtk.enable = true;

      services.gnome.gnome-keyring.enable = true;
      services.upower.enable = true;
    })
    {
      hardware.bluetooth = lib.mkIf config.yomi.machine.bluetooth {
        enable = true;
        powerOnBoot = true;
      };
    }
  ];
}
