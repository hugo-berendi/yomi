{
  config,
  lib,
  ...
}: let
  cfg = config.yomi.restic;

  # {{{ Backup helper
  createBackup = {
    name,
    paths,
    exclude,
    pruneOpts,
  }: {
    inherit pruneOpts paths;

    initialize = true;
    repository = "${cfg.repository}/${name}";
    passwordFile = config.sops.secrets.backup_password.path;
    inherit (cfg) extraOptions;

    exclude =
      [
        # Syncthing / direnv / git stuff
        ".direnv"
        ".git"
        ".stfolder"
        ".stversions"
      ]
      ++ exclude;
  };
  # }}}
in {
  options.yomi.restic = {
    enable = lib.mkEnableOption "yomi's restic backup integration";

    # This used to be read out of a url.txt that was never committed, so the
    # module could not be enabled at all without an eval failure.
    repository = lib.mkOption {
      type = lib.types.str;
      example = "sftp:user@host:backups";
      description = ''
        Base restic repository. Each backup set appends its own name, so a
        local path and an sftp target both work.
      '';
    };

    extraOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["sftp.args='-i /home/user/.ssh/id_ed25519'"];
      description = "Extra restic options, e.g. the ssh key for an sftp repository.";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets.backup_password.sopsFile = ../../secrets.yaml;

    services.restic.backups = {
      # {{{ Data
      data = createBackup {
        name = "data";
        pruneOpts = [
          "--keep-daily 7"
          "--keep-weekly 4"
          "--keep-monthly 12"
          "--keep-yearly 0"
        ];

        paths = ["/persist/data"];
        exclude = [
          # projects are available on github and in my own forge already
          "/persist/data${config.users.users.${config.yomi.pilot.name}.home}/projects"
        ];
      };
      # }}}
      # {{{ State
      state = createBackup {
        name = "state";
        pruneOpts = [
          "--keep-daily 3"
          "--keep-weekly 1"
          "--keep-monthly 1"
          "--keep-yearly 0"
        ];

        paths = ["/persist/state"];
        exclude = let
          home = "/persist/state/${config.users.users.${config.yomi.pilot.name}.home}";
        in [
          "${home}/discord" # There's lots of cache stored in here
          "${home}/steam" # Games can be quite big
        ];
      };
      # }}}
    };
  };
}
