{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.yomi.anubis;
in {
  options.yomi.anubis = {
    enable = lib.mkEnableOption "yomi's anubis integration";
  };

  config = lib.mkIf cfg.enable {
    services.anubis = {
      package = pkgs.anubis;
      defaultOptions = {
        enable = true;
        settings = {
          SERVE_ROBOTS_TXT = true;
        };
      };
    };
  };
}
