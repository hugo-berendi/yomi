{
  config,
  lib,
  ...
}: let
  cfg = config.yomi.wireless;
  networks = import ./networks.nix;
in {
  config = lib.mkIf (cfg.enable && cfg.backend == "wpa-supplicant") {
    sops.secrets.wireless.sopsFile = ../secrets.yaml;

    # https://github.com/NixOS/nixpkgs/blob/nixos-22.11/nixos/modules/services/networking/wpa_supplicant.nix

    networking.wireless = {
      enable = true;
      fallbackToWPA2 = false;

      # Declarative
      secretsFile = config.sops.secrets.wireless.path;
      networks =
        lib.mapAttrs (_: network: {
          pskRaw = "ext:${network.pskEnv}";
          priority = network.priority;
          authProtocols = [
            "WPA-PSK"
            "SAE"
          ];
        })
        networks;

      # Imperative
      allowAuxiliaryImperativeNetworks = true;
      userControlled = {
        enable = true;
        group = "network";
      };
    };

    # Ensure group exists
    users.groups.network = {};
    users.users.pilot.extraGroups = ["network"];

    # The service seems to fail if this file does not exist
    systemd.tmpfiles.rules = ["f /etc/wpa_supplicant.conf"];
  };
}
