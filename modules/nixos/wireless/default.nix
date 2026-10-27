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

      default = "networkmanager";
      type = lib.types.enum [
        "networkmanager"
      ];
    };

    sopsFile = lib.mkOption {
      type = lib.types.path;
      description = "sops file holding the wireless secret (the PSK environment variables).";
    };
  };

  imports = [
    ./networkmanager.nix
  ];
}
