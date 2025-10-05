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
    ../common/optional/yubikey.nix
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

  yomi.pilot.name = "hugob";
}
