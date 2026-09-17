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

      # Ahead of the restic timers at 00:00, not after them. Dumping at 02:30
      # meant the nightly backup always captured the previous day's dump, so
      # the database lagged the file data it describes by about 22 hours --
      # long enough for a photo to be in the immich backup while the row
      # describing it is not.
      startAt = "*-*-* 23:30:00";
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
