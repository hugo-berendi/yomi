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

  # udev rules so the pilot can use the YubiKey as a FIDO2 SSH authenticator
  # (ssh-keygen -t ed25519-sk) without root. libfido2 ships its own rules;
  # openssh's built-in security-key support needs no separate provider.
  services.udev.packages = [pkgs.libfido2];
  environment.systemPackages = [
    pkgs.libfido2 # fido2-token, for diagnostics
    pkgs.yubikey-manager # ykman: OpenPGP PINs and touch policies, PIV
    pkgs.age-plugin-yubikey # sops' PIV recipient
  ];

  # The OpenPGP and PIV applets are reached through pcscd, which ykman and
  # age-plugin-yubikey require. scdaemon would rather claim the USB device
  # with its own CCID driver, which locks pcscd out until scdaemon is killed,
  # so home/amaterasu.nix sets disable-ccid and gpg goes through pcscd too.
  # hardware.gpgSmartcards is left off: its udev rules exist only to give
  # that CCID driver the device.
  services.pcscd.enable = true;

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
