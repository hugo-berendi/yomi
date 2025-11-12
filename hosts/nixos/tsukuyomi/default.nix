{
  lib,
  pkgs,
  config,
  ...
}: {
  # {{{ Imports
  imports = [
    ../common

    ../common/desktop/steam.nix

    ./hardware
    ./filesystems
  ];
  # }}}

  system.stateVersion = "24.05";

  yomi.pilot.name = "hugob";
  yomi.machine.graphical = true;
  yomi.machine.gaming = true;
  yomi.machine.interactible = true;
  yomi.wireless.enable = true;
  yomi.wireless.backend = "wpa-supplicant";

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
}
