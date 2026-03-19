{
  lib,
  config,
  ...
}: {
  users.users.${config.yomi.pilot.name}.extraGroups = ["networkmanager"];

  imports = [
    ./dnsmasq.nix
    ./hostapd.nix
    ./networkd.nix
    ./nftables.nix
  ];

  networking.wireless.enable = lib.mkForce false;
  networking.wireless.interfaces = ["wlp2s0"];
}
