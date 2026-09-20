{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.yomi.restic;
  outerConfig = config;
  enabledSets = lib.filterAttrs (_: set: set.enable) cfg.sets;
  backupNames = lib.attrNames enabledSets;
  metricsDirectory = "/var/lib/restic-metrics";
in {
  options.yomi.restic = {
    enable = lib.mkEnableOption "yomi's restic backup integration";

    sopsFile = lib.mkOption {
      type = lib.types.path;
      description = "Encrypted file providing the shared backup_password secret.";
    };
    sets = lib.mkOption {
      default = {};
      description = "Named backup and check jobs. Paths, credentials, retention and prerequisite units belong to each set.";
      type = lib.types.attrsOf (lib.types.submodule ({
        name,
        config,
        ...
      }: {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable this backup job.";
          };
          repository = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default =
              if config.repositoryFile != null || cfg.repository == null
              then null
              else "${cfg.repository}/${name}";
            description = "Restic repository, mutually exclusive with repositoryFile.";
          };
          repositoryFile = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Runtime file containing the repository URL.";
          };
          passwordFile = lib.mkOption {
            type = lib.types.str;
            default = outerConfig.sops.secrets.backup_password.path;
            description = "Runtime repository password file.";
          };
          environmentFile = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Runtime environment file providing backend credentials.";
          };
          paths = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Explicit paths to back up; an empty set can run checks only.";
          };
          exclude = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Restic exclusion patterns.";
          };
          pruneOpts = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Retention and prune arguments.";
          };
          checkOpts = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Integrity check arguments.";
          };
          extraOptions = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = cfg.extraOptions;
            description = "Restic backend options.";
          };
          extraBackupArgs = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Additional backup arguments.";
          };
          initialize = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Initialize the repository when missing.";
          };
          timerConfig = lib.mkOption {
            type = lib.types.attrsOf lib.types.anything;
            default = {
              OnCalendar = "daily";
              Persistent = true;
            };
            description = "Native systemd timer settings.";
          };
          requires = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Units required to complete before backup, such as database dumps.";
          };
        };
      }));
    };
    # This used to be read out of a url.txt that was never committed, so the
    # module could not be enabled at all without an eval failure.
    repository = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
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
    {
      assertions =
        lib.mapAttrsToList (name: set: {
          assertion = (set.repository != null) != (set.repositoryFile != null);
          message = "Restic set ${name} needs exactly one of repository and repositoryFile.";
        })
        enabledSets;
      services.restic.backups = lib.mapAttrs (_: set: builtins.removeAttrs set ["enable" "requires"]) enabledSets;
      # ExecStartPost runs only after backup, prune and check all succeeded.
      # Keep the previous timestamp on failure, including across a reboot.
      systemd.services = lib.genAttrs (map (name: "restic-backups-${name}") backupNames) (unit: let
        name = lib.removePrefix "restic-backups-" unit;
      in {
        requires = cfg.sets.${name}.requires;
        after = cfg.sets.${name}.requires;
        postStart = ''
          set -eu
          metric=${metricsDirectory}/${name}.prom
          tmp="$metric.tmp"
          trap 'rm -f "$tmp"' EXIT
          printf '# HELP yomi_restic_last_success_timestamp_seconds Unix timestamp of the last successful restic job.\n# TYPE yomi_restic_last_success_timestamp_seconds gauge\n' > "$tmp"
          printf 'yomi_restic_last_success_timestamp_seconds{host="%s",backup="%s"} %s\n' \
            ${lib.escapeShellArg config.networking.hostName} ${lib.escapeShellArg name} \
            "$(${pkgs.coreutils}/bin/date +%s)" >> "$tmp"
          chmod 0644 "$tmp"
          mv -f "$tmp" "$metric"
        '';
      });

      systemd.tmpfiles.rules = ["d ${metricsDirectory} 0755 root root -"];
      environment.persistence."/persist/state".directories = [metricsDirectory];
      services.prometheus.exporters.node.extraFlags = [
        "--collector.textfile.directory=${metricsDirectory}"
      ];
    }
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

      yomi.restic.sets.offsite = {
        extraOptions = [];
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

      # Checking B2 separately keeps a slow download out of the nightly backup.
      yomi.restic.sets.offsite-check = {
        extraOptions = [];
        inherit (cfg.sets.offsite) repositoryFile passwordFile environmentFile;
        checkOpts = ["--retry-lock=30m" "--read-data-subset=5%"];
        timerConfig = {
          OnCalendar = "Sun *-*-* 04:00:00";
          RandomizedDelaySec = "1h";
          Persistent = true;
        };
      };

      systemd.services = lib.mkIf cfg.sets.offsite.enable {
        restic-backups-offsite.serviceConfig = {
          TimeoutStartSec = "infinity";
          # Metered uplink shared with everything else in the house.
          CPUSchedulingPolicy = "idle";
          IOSchedulingClass = "idle";
        };
      };
    })
    {sops.secrets.backup_password.sopsFile = cfg.sopsFile;}
  ]);
}
