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

      # Restic starts a fresh dump and waits for success. Clock offsets alone
      # neither wait for a slow dump nor propagate its failure.
      startAt = lib.mkIf config.yomi.restic.enable [];
    };

    yomi.restic.sets = lib.mkIf config.yomi.restic.enable {
      state.requires = ["postgresqlBackup.service"];
      offsite = lib.mkIf config.yomi.restic.offsite.enable {requires = ["postgresqlBackup.service"];};
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
