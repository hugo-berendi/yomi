{
  lib,
  pkgs,
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
  yomi.wireless.backend = "networkmanager";

  boot.loader.systemd-boot.enable = true;

  # {{{ Machine ids
  networking.hostName = "tsukuyomi";
  # }}}
  # {{{ DNS records
  # Intentionally empty. This machine runs Windows now, so nothing here claims
  # an address for it.
  #
  # The records that used to live here were 100.127.234.95 and
  # fd7a:115c:a1e0::501:ea5e, which are amaterasu's addresses with the last
  # character changed -- they never matched a tailscale node. The two real
  # tsukuyomi nodes are 100.108.206.114 and 100.124.169.22, both last seen in
  # 2026-04 and 2026-05. Repopulate this from `tailscale status` if the host
  # is ever reinstalled.
  yomi.dns.records = [];
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
    package = pkgs.mysql84;
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
}
