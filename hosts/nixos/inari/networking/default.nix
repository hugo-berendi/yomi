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
  networking.wireless.interfaces = lib.optional (config.yomi.inari.wifiInterface != null) config.yomi.inari.wifiInterface;
}
