{
  config,
  lib,
  ...
}: let
  cfg = config.yomi.wireless;
  networks = import ./networks.nix;
in {
  config = lib.mkIf (cfg.enable && cfg.backend == "networkmanager") {
    sops.secrets.wireless.sopsFile = ../secrets.yaml;

    networking.networkmanager = {
      enable = true;
      wifi.backend = "wpa_supplicant";

      ensureProfiles = {
        environmentFiles = [config.sops.secrets.wireless.path];
        profiles =
          lib.mapAttrs
          (
            ssid: network: {
              connection = {
                id = ssid;
                type = "wifi";
                autoconnect = true;
                autoconnect-priority = 100 - network.priority;
                permissions = "";
              };

              wifi = {
                mode = "infrastructure";
                ssid = ssid;
              };

              wifi-security = {
                key-mgmt = "wpa-psk";
                psk = "${"$"}${network.pskEnv}";
              };

              ipv4 = {
                method = "auto";
                dns-search = "";
              };

              ipv6 = {
                method = "auto";
                dns-search = "";
                addr-gen-mode = "stable-privacy";
              };
            }
          )
          networks;
      };
    };

    networking.wireless.enable = lib.mkForce false;

    users.users.pilot.extraGroups = ["networkmanager"];
  };
}
