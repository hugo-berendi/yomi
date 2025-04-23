{config, ...}: {
  sops.secrets.wireless.sopsFile = ../../secrets.yaml;

  # https://github.com/NixOS/nixpkgs/blob/nixos-22.11/nixos/modules/services/networking/wpa_supplicant.nix

  networking.wireless = {
    enable = true;
    fallbackToWPA2 = false;

    # Declarative
    secretsFile = config.sops.secrets.wireless.path;
    networks = {
      "Susanoo" = {
        pskRaw = "ext:SUSANOO_HOTSPOT_PASS";
        priority = 0;
        authProtocols = [
          "WPA-PSK"
          "SAE"
        ];
      };
      "FRITZ!Box 6591 Cable OY" = {
        pskRaw = "ext:HOME_WIFI_PASS";
        priority = 1;
        authProtocols = [
          "WPA-PSK"
          "SAE"
        ];
      };
      "KROKOnet" = {
        pskRaw = "ext:KROKOnet_WIFI_PASS";
        priority = 2;
        authProtocols = [
          "WPA-PSK"
          "SAE"
        ];
      };
    };

    # Imperative
    allowAuxiliaryImperativeNetworks = true;
    userControlled = {
      enable = true;
      group = "network";
    };
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Experimental = true;
      };
    };
  };

  services.blueman.enable = true;

  # Ensure group exists
  users.groups.network = {};

  # The service seems to fail if this file does not exist
  systemd.tmpfiles.rules = ["f /etc/wpa_supplicant.conf"];
}
