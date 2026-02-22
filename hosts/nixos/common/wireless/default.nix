{lib, ...}: {
  options.yomi.wireless = {
    enable =
      lib.mkEnableOption "yomi's WIFI integration"
      // {
        default = true;
      };

    backend = lib.mkOption {
      description = ''
        Determines which backend should be used for WIFI connectivity.
      '';

      type = lib.types.enum [
        "iwd"
        "networkmanager"
        "wpa-supplicant"
      ];
    };
  };

  imports = [
    ./iwd
    ./networkmanager.nix
    ./wpa_supplicant.nix
  ];
}
