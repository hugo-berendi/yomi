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

    checkOpts = ["--with-cache" "--read-data-subset=5%"];
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

    # {{{ Off-site
    offsite = {
      enable = lib.mkEnableOption ''
        a second restic repository on storage that does not share a failure
        domain with this machine.

        The repositories above live on a pool inside the same box, which
        covers losing a disk but not losing the box
      '';

      sopsFile = lib.mkOption {
        type = lib.types.path;
        example = lib.literalExpression "./secrets.yaml";
        description = ''
          Secrets file providing b2_bucket, b2_account_id and b2_account_key.

          This module lives in common/, so a relative path here would resolve
          against common/ and miss the per-host file the credentials actually
          belong in. backup_password stays in common/secrets.yaml because it is
          genuinely shared.
        '';
      };

      paths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = ''
          Paths to send off-site. Deliberately separate from the local sets:
          this is metered storage, so it should hold what cannot be
          reacquired, not everything.
        '';
      };

      exclude = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Extra exclude patterns for the off-site set.";
      };

      pruneOpts = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "--keep-daily 7"
          "--keep-weekly 4"
          "--keep-monthly 12"
          "--keep-yearly 3"
        ];
        description = ''
          Retention for the off-site set. Longer than the local sets by
          design: this is the copy that survives the house.
        '';
      };
    };
    # }}}
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    (lib.mkIf cfg.offsite.enable {
      sops.secrets.b2_bucket.sopsFile = cfg.offsite.sopsFile;
      sops.secrets.b2_account_id.sopsFile = cfg.offsite.sopsFile;
      sops.secrets.b2_account_key.sopsFile = cfg.offsite.sopsFile;

      # Bucket names are globally unique across all of B2 and so are worth
      # keeping out of a repository that is mirrored to a public forge. That
      # means the repository string cannot be built in nix, since the bucket
      # is only known at activation -- hence a rendered template rather than a
      # plain string. No trailing newline: restic reads this file verbatim.
      sops.templates."restic-b2-repository".content = "b2:${config.sops.placeholder.b2_bucket}:${config.networking.hostName}";

      sops.templates."restic-b2.env".content = ''
        B2_ACCOUNT_ID=${config.sops.placeholder.b2_account_id}
        B2_ACCOUNT_KEY=${config.sops.placeholder.b2_account_key}
      '';

      services.restic.backups.offsite = {
        initialize = true;
        inherit (cfg.offsite) paths exclude pruneOpts;

        repositoryFile = config.sops.templates."restic-b2-repository".path;
        passwordFile = config.sops.secrets.backup_password.path;
        environmentFile = config.sops.templates."restic-b2.env".path;

        # The first run ships the whole set over the uplink; let it take as
        # long as it takes rather than being killed mid-transfer.
        timerConfig = {
          OnCalendar = "daily";
          RandomizedDelaySec = "1h";
          Persistent = true;
        };
      };

      systemd.services.restic-backups-offsite.serviceConfig = {
        TimeoutStartSec = "infinity";
        # Metered uplink shared with everything else in the house.
        CPUSchedulingPolicy = "idle";
        IOSchedulingClass = "idle";
      };
    })
    {
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
    }
  ]);
}
