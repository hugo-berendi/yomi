{
  lib,
  modulesPath,
  ...
}: {
  imports = [
    ../common/vps.nix
    "${modulesPath}/profiles/qemu-guest.nix"
    ./filesystems.nix
  ];

  networking.hostName = "ebisu";
  system.stateVersion = "26.05";

  # Listener definitions can be inspected before the gateway is provisioned.
  yomi.expose.server.sourceHosts = ["inari"];

  # Confirm the provider's addresses and routes from the rescue system before
  # installation; no guessed public addresses are published in DNS.
  networking.useDHCP = false;
  networking.useNetworkd = true;
  systemd.network.networks."10-uplink" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = true;
    };
  };

  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
    configurationLimit = 3;
  };
  boot.loader.efi.canTouchEfiVariables = false;

  # The persistent root keeps SSH keys and service state across reboots.
  services.qemuGuest.enable = true;
  services.fstrim.enable = lib.mkDefault true;

  warnings = [
    "ebisu is a bootstrap configuration: replace the disk placeholder and verify firmware, DHCP IPv4 and IPv6 routes before installing."
  ];
}
