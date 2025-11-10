{
  config,
  lib,
  ...
}: let
  cfg = config.yomi.postgres;
in {
  options.yomi.postgres = {
    enable = lib.mkEnableOption "yomi's postgres integration";
  };

  config = lib.mkIf cfg.enable {
    services.postgresql = {
      enable = true;
    };

    environment.persistence."/persist/state".directories = [
      {
        directory = "/var/lib/postgresql";
        user = config.users.users.postgres.name;
        group = config.users.users.postgres.group;
      }
    ];
  };
}
