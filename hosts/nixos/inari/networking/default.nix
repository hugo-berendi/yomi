{ lib, config, ... }:
{
  users.users.pilot.extraGroups = [ "networkmanager" ];

  imports = [
    ./dnsmasq.nix
    ./hostapd.nix
    ./networkd.nix
    ./nftables.nix
  ];

  networking.wireless.enable = lib.mkForce false;
  networking.wireless.interfaces = [ "wlp2s0" ];
}