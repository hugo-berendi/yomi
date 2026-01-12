{
  config,
  lib,
  inputs,
  ...
}: let
  cfg = config.yomi.playit;
in {
  options.yomi.playit = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to enable the playit.gg tunneling service";
    };

    secretPath = lib.mkOption {
      type = lib.types.path;
      description = "Path to the playit secret file";
    };
  };

  config = lib.mkIf cfg.enable {
    services.playit = {
      enable = true;
      secretPath = cfg.secretPath;
    };
  };
}
