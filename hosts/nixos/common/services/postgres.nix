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

    systemd.services = lib.mkIf config.yomi.restic.enable (lib.genAttrs
      (["restic-backups-state"] ++ lib.optional config.yomi.restic.offsite.enable "restic-backups-offsite")
      (_: {
        requires = ["postgresqlBackup.service"];
        after = ["postgresqlBackup.service"];
      }));

    environment.persistence."/persist/state".directories = [
      {
        directory = "/var/lib/postgresql";
        user = config.users.users.postgres.name;
        group = config.users.users.postgres.group;
      }
    ];
  };
}
