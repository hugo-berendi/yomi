{
  lib,
  pkgs,
  ...
}: let
  brightnessctl = lib.getExe pkgs.brightnessctl;
  hyprctl = lib.getExe' pkgs.hyprland "hyprctl";
  hyprlock = lib.getExe pkgs.hyprlock;

  # The YubiKey stands in for presence: while it is plugged in, idling does
  # not lock, and pulling it out locks at once (the udev rule in
  # hosts/nixos/amaterasu/yubikey.nix). 1050 is Yubico's USB vendor id.
  # Only the lock is skipped -- dimming, screen-off and suspend still run,
  # and suspending still locks through before_sleep_cmd.
  lockUnlessYubikey = pkgs.writeShellScript "lock-unless-yubikey" ''
    if ${lib.getExe pkgs.gnugrep} -qsx 1050 /sys/bus/usb/devices/*/idVendor; then
      exit 0
    fi
    exec ${lib.getExe' pkgs.systemd "loginctl"} lock-session
  '';
in {
  services.hypridle = {
    enable = true;
    importantPrefixes = [];
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || ${hyprlock}";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "${hyprctl} dispatch dpms on";
      };

      listener = [
        {
          timeout = 300;
          on-timeout = "${brightnessctl} -s set 10%";
          on-resume = "${brightnessctl} -r";
        }
        {
          timeout = 600;
          on-timeout = "${lockUnlessYubikey}";
        }
        {
          timeout = 660;
          on-timeout = "${hyprctl} dispatch dpms off";
          on-resume = "${hyprctl} dispatch dpms on";
        }
        {
          timeout = 3600;
          on-timeout = "systemctl suspend";
        }
      ];
    };
  };
}
