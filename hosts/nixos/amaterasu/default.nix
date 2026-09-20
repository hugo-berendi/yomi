{
  config,
  pkgs,
  ...
}: {
  # {{{ Imports
  imports = [
    {yomi.tailscale.enable = true;}
    ../common

    ../common/desktop/steam.nix
    ../common/services/yubikey.nix

    ./hardware
    ./filesystems
    ./services/restic.nix
  ];
  # }}}

  system.stateVersion = "24.05";

  yomi.pilot.name = "hugob";
  yomi.machine.graphical = true;
  yomi.machine.gaming = true;
  yomi.machine.interactible = true;
  yomi.wireless.enable = true;
  yomi.wireless.backend = "networkmanager";

  boot.kernelPackages = pkgs.linuxPackages_6_12;
  boot.loader.systemd-boot.enable = true;

  # {{{ Machine ids
  networking.hostName = "amaterasu";
  environment.etc.machine-id.text = "08357db3540c4cd2b76d4bb7f825ec88";
  # }}}
  # {{{ DNS records
  yomi.dns.records = [
    {
      at = config.networking.hostName;
      type = "A";
      value = "100.127.234.94";
    }
    {
      at = config.networking.hostName;
      type = "AAAA";
      value = "fd7a:115c:a1e0::501:ea5f";
    }
  ];
  # }}}
}
