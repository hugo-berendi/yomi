{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}: let
  ipv4 = "62.83.116.214";
  ipv6 = "2a03:4000:16:16e1:78f7:e3ff:fe9b:63c0";
  inherit (config.yomi.expose) publicHost;
in {
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
  # NixOS derives the PAM default from global PasswordAuthentication, which
  # stays off because only the pilot's Match block enables it.
  security.pam.services.sshd.unixAuth = lib.mkForce true;

  yomi.expose.server = {
    enable = true;
    sourceHosts = ["inari"];
    edition = "enterprise";
    environmentFile = "/var/lib/yomi/pangolin.env";
    geoip.enable = true;
  };
  # Managed client DNS first shipped in 1.27.
  services.pangolin = {
    package = pkgs.callPackage ../../../pkgs/pangolin.nix {
      inherit (config.yomi.expose.server) edition;
    };
    settings.flags.enable_integration_api = true;
  };
  services.traefik.dynamicConfigOptions.http.routers = let
    localApi = lib.mkForce "Host(`api.${config.yomi.expose.domain}`) && (ClientIP(`127.0.0.1`) || ClientIP(`::1`))";
  in {
    int-api-router.rule = localApi;
    int-api-router-redirect.rule = localApi;
  };
  yomi.dns.records = [
    {
      at = "ebisu";
      type = "A";
      value = ipv4;
    }
    {
      at = "ebisu";
      type = "AAAA";
      value = ipv6;
    }
    {
      at = "pangolin";
      type = "CNAME";
      value = "${publicHost}.";
    }
  ];
  yomi.ssh.extraHostNames = [publicHost ipv4 ipv6];

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
      "${ipv4}/22"
      "${ipv6}/64"
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
