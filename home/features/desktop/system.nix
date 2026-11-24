{
  config,
  lib,
  ...
}: {
  imports = [
    ./audio/system.nix
    ./xdg-portal/system.nix
    ./file-manager/system.nix
    ./gaming/system.nix
    ./unicode/system.nix
    ./quietboot/system.nix
    ../wayland/hyprland/system.nix
    ./browser/system.nix
  ];

  config = lib.mkMerge [
    (lib.mkIf config.yomi.machine.graphical {
      stylix.targets.gtk.enable = true;

      services.gnome.gnome-keyring.enable = true;
      services.upower.enable = true;

      # Partition and format USB sticks and SD cards without a terminal; the
      # module also installs the udisks2 polkit glue it needs.
      programs.gnome-disks.enable = true;

      # A unit that ignores SIGTERM holds up shutdown for the default 90 s
      # ("A stop job is running ..."). On a desktop nothing needs that long to
      # stop cleanly; Omarchy uses 5 s, 10 s leaves room for a restic run or a
      # browser flushing its profile. Servers (inari) keep the default.
      systemd.settings.Manager.DefaultTimeoutStopSec = "10s";
      systemd.user.extraConfig = "DefaultTimeoutStopSec=10s";
    })
    {
      hardware.bluetooth = lib.mkIf config.yomi.machine.bluetooth {
        enable = true;
        powerOnBoot = true;
      };
    }
  ];
}
