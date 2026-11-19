{
  config,
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

  users.users.${config.yomi.pilot.name} = {
    hashedPassword = lib.mkForce null;
    # Provision the hash on Ebisu so it stays out of Git and the Nix store.
    hashedPasswordFile = "/var/lib/yomi/ebisu-password.hash";
    openssh.authorizedKeys.keyFiles = [./keys/inari-admin.pub];
  };

  services.openssh.extraConfig = lib.mkAfter ''
    Match User ${config.yomi.pilot.name}
      PasswordAuthentication yes
    Match all
  '';

  # Listener definitions can be inspected before the gateway is provisioned.
  yomi.expose.server.sourceHosts = ["inari"];
  # License activation and GeoLite2 enrollment happen after the VPS bootstrap.
  yomi.expose.server.edition = "enterprise";
  yomi.expose.server.geoip.enable = true;

  # The netcup Debian image uses static addresses on both IP families.
  networking.useDHCP = false;
  networking.useNetworkd = true;
  networking.nameservers = ["46.38.252.230" "46.38.225.230" "2a03:4000:8000::fce6"];
  systemd.network.networks."10-uplink" = {
    matchConfig.MACAddress = "7a:f7:e3:9b:63:c0";
    networkConfig = {
      DHCP = "no";
      IPv6AcceptRA = false;
    };
    address = [
      "62.83.116.214/22"
      "2a03:4000:16:16e1:78f7:e3ff:fe9b:63c0/64"
    ];
    routes = [
      {
        Gateway = "62.83.116.1";
        GatewayOnLink = true;
      }
      {
        Gateway = "fe80::1";
        GatewayOnLink = true;
      }
    ];
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
}
