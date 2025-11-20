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

    user = lib.mkOption {
      type = lib.types.str;
      default = "playit";
      description = "User to run the playit service as";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "playit";
      description = "Group to run the playit service as";
    };

    secretPath = lib.mkOption {
      type = lib.types.path;
      description = "Path to the playit secret file";
    };
  };

  config = lib.mkIf cfg.enable {
    services.playit = {
      enable = true;
      user = cfg.user;
      group = cfg.group;
      secretPath = cfg.secretPath;
    };
  };
}
