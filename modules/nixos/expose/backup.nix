{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.yomi.expose.server;
  inherit (cfg) backup;
  runtimeFile = value: value != null && lib.hasPrefix "/" value && !lib.hasPrefix "/nix/store/" value;
  helper = builtins.path {
    path = ./backup.py;
    name = "expose-backup.py";
  };
in {
  options.yomi.expose.server.backup = {
    enable = lib.mkEnableOption "encrypted off-host Restic backups of Pangolin, certificates, keys and server credentials";
    repositoryFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Runtime file with the URL of an already initialized off-host Restic repository.";
    };
    passwordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Runtime Restic encryption password file.";
    };
    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional runtime storage access credentials.";
    };
  };
  config = lib.mkIf (cfg.enable && backup.enable) {
    assertions = [
      {
        assertion = runtimeFile backup.repositoryFile && runtimeFile backup.passwordFile && (backup.environmentFile == null || runtimeFile backup.environmentFile);
        message = "Expose backups need runtime repository/password files outside the Nix store.";
      }
    ];
    services.restic.backups.expose = {
      inherit (backup) repositoryFile passwordFile environmentFile;
      initialize = false;
      paths = ["/var/lib/expose-backup"];
      backupPrepareCommand = ''
        ${lib.getExe pkgs.python3} ${helper} ${lib.escapeShellArgs [config.services.pangolin.dataDir cfg.environmentFile "/var/lib/expose-backup"]}
      '';
      pruneOpts = ["--keep-daily 7" "--keep-weekly 4" "--keep-monthly 3"];
      checkOpts = ["--read-data-subset=5%"];
      timerConfig = {
        OnCalendar = "daily";
        RandomizedDelaySec = "1h";
        Persistent = true;
      };
    };
    systemd.services.restic-backups-expose.serviceConfig.UMask = "0077";
  };
}
