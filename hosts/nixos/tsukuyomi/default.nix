{
  lib,
  pkgs,
  config,
  ...
}: {
  # {{{ Imports
  imports = [
    ../common/global
    ../common/users/pilot.nix

    ../common/optional/bluetooth.nix
    ../common/optional/greetd.nix
    ../common/optional/oci.nix
    ../common/optional/quietboot.nix
    ../common/optional/desktop-base.nix

    ../common/optional/desktop
    ../common/optional/desktop/steam.nix
    ../common/optional/wayland/hyprland.nix

    ../common/optional/services/nginx.nix
    ../common/optional/services/syncthing.nix

    ./hardware
    ./filesystems
    ../common/optional/grub.nix
  ];
  # }}}

  system.stateVersion = "24.05";

  # {{{ Machine ids
  networking.hostName = "tsukuyomi";
  # }}}
  # {{{ DNS records
  yomi.dns.records = [
    {
      at = config.networking.hostName;
      type = "A";
      value = "100.127.234.95";
    }
    {
      at = config.networking.hostName;
      type = "AAAA";
      value = "fd7a:115c:a1e0::501:ea5e";
    }
  ];
  # }}}
  # {{{ Hardware
  hardware.enableAllFirmware = true;
  hardware.graphics.enable = true;
  powerManagement.cpuFreqGovernor = "ondemand";
  services.power-profiles-daemon.enable = lib.mkDefault true;
  # }}}
  # {{{ Services
  services.printing.enable = true;
  services.mysql = {
    enable = true;
    package = pkgs.mysql80;
  };
  # }}}
  # {{{ Stylix
  stylix.targets.gtk.enable = true;
  # }}}
  # {{{ Site blocking
  networking.extraHosts = let
    blacklisted = [
      "minesweeper.online"
    ];
    blacklist = lib.concatStringsSep "\n" (lib.forEach blacklisted (host: "127.0.0.1 ${host}"));
  in
    blacklist;
  # }}}
  # {{{ Environment overrides
  environment.systemPackages = with pkgs; [
    dunst
  ];
  # }}}

  yomi.pilot.name = "hugob";
}
