{
  lib,
  config,
  ...
}: {
  users.users.${config.yomi.pilot.name}.extraGroups = ["networkmanager"];

  imports = [
    ./dnsmasq.nix
    ./networkd.nix
    ./nftables.nix
  ];

  networking.wireless.enable = lib.mkForce false;
}
