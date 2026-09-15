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

    services.postgresqlBackup = {
      enable = true;
      backupAll = true;
      compression = "zstd";
      location = "/persist/state/var/backup/postgresql";
      startAt = "*-*-* 02:30:00";
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
