# A dedicated Forgejo Actions worker for a machine of its own.
#
# It wraps the native `services.gitea-actions-runner` module rather than
# replacing it, keeps the `native:host` label the workflows already ask for,
# and differs from inari's production runner in three deliberate ways:
#
# - It is never a nix trusted user. The production runner was trusted only so
#   nix would honour the flake's `extra-trusted-public-keys`; a worker whose
#   root nix.conf already lists the same caches gets them without that, and
#   the assertion below refuses a build where that is not the case. Pushing to
#   cachix uses cachix's own token and needs no trust either.
# - It keeps the upstream DynamicUser, so the job user owns nothing outside
#   the runner's state directory, and credentials reach it as files the
#   service manager reads as root (EnvironmentFile, LoadCredential).
# - One job at a time, and the runner and the nix-daemon share one slice, so
#   the builds a job sends to the daemon count against the same limit as the
#   job itself. On inari only the runner's evaluators were inside its limit.
#
# The worker must not be the forge host: assertions refuse a machine that also
# runs Forgejo. Registration, network reachability of `url` and every
# credential file are the host's responsibility; this module only consumes
# paths.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.yomi.forgejoCiWorker;

  # The upstream module names the unit gitea-runner-<instance>.
  instance = "ci";
  unit = "gitea-runner-${instance}";
  slice = "forgejo-ci";
  sshKeyCredential = "git-ssh-key";

  caches = import ../../common/caches.nix;
  rootSubstituters = (config.nix.settings.substituters or []) ++ (config.nix.settings.extra-substituters or []);
  rootKeys = (config.nix.settings.trusted-public-keys or []) ++ (config.nix.settings.extra-trusted-public-keys or []);
  missingCaches = lib.subtractLists rootSubstituters cfg.requiredSubstituters;
  missingKeys = lib.subtractLists rootKeys cfg.requiredTrustedPublicKeys;

  trustedUsers = config.nix.settings.trusted-users or [];
  isStorePath = p: lib.hasPrefix "${builtins.storeDir}/" (toString p);
in {
  # {{{ Options
  options.yomi.forgejoCiWorker = {
    enable = lib.mkEnableOption "a dedicated, untrusted Forgejo Actions worker";

    name = lib.mkOption {
      type = lib.types.str;
      default = "${config.networking.hostName}-ci";
      defaultText = lib.literalExpression ''"''${config.networking.hostName}-ci"'';
      description = "Runner name registered in Forgejo. Use a name distinct from the production runner's.";
    };

    url = lib.mkOption {
      type = lib.types.str;
      example = "https://git.example.org";
      description = "Forgejo instance the worker registers with and polls for jobs.";
    };

    tokenFile = lib.mkOption {
      type = lib.types.str;
      example = "/run/secrets/forgejo-ci-worker-token.env";
      description = ''
        Environment file holding `TOKEN=<registration token>`, read by the
        service manager as root. Use a token issued for this worker alone, so
        it can be revoked without touching the production runner.
      '';
    };

    labels = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["native:host"];
      description = "Runner labels. `native:host` matches `runs-on: native` in the existing workflows.";
    };

    hostPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      # Same set as inari's production runner, so the workflows see the tools
      # they already rely on.
      default = with pkgs; [
        bash
        coreutils
        curl
        gawk
        gitMinimal
        gnused
        hostname
        nix
        nodejs
        openssh
        wget
        just
        stylua
        python313
      ];
      defaultText = lib.literalMD "the production runner's tool set";
      description = "Packages on the PATH of `host` jobs.";
    };

    environmentFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["/run/secrets/forgejo-ci-worker-nix.env"];
      description = ''
        Extra environment files for the runner, read as root. The usual one
        sets `NIX_CONFIG=access-tokens = github.com=<token>` to lift the
        anonymous GitHub API rate limit on flake input resolution.
      '';
    };

    gitSshKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Private key for ssh:// flake inputs (the read-only deploy key of the
        `skills` input). Passed through LoadCredential, so only this unit's
        dynamic user can read its copy. Issue a key for this worker alone.
      '';
    };

    requiredSubstituters = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = caches.substituters;
      defaultText = lib.literalExpression "(import common/caches.nix).substituters";
      description = ''
        Caches that root's nix.conf must already list. An untrusted runner
        cannot accept the flake's own nixConfig, so a cache missing here is
        silently not used.
      '';
    };

    requiredTrustedPublicKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = caches.trustedPublicKeys;
      defaultText = lib.literalExpression "(import common/caches.nix).trustedPublicKeys";
      description = "Signing keys that root's nix.conf must already trust.";
    };

    # {{{ Resources
    resources = {
      maxJobs = lib.mkOption {
        type = lib.types.ints.positive;
        default = 1;
        description = "nix `max-jobs` on the worker: concurrent derivation builds.";
      };

      cores = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 2;
        description = "nix `cores` per build; 0 means every core.";
      };

      memoryHigh = lib.mkOption {
        type = lib.types.str;
        default = "6G";
        description = "MemoryHigh of the slice holding the runner and the nix-daemon.";
      };

      memoryMax = lib.mkOption {
        type = lib.types.str;
        default = "8G";
        description = "MemoryMax of the slice holding the runner and the nix-daemon.";
      };

      memorySwapMax = lib.mkOption {
        type = lib.types.str;
        default = "1G";
        description = "MemorySwapMax of the slice.";
      };

      cpuQuota = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "300%";
        description = "Optional CPUQuota of the slice. Unset leaves the machine's CPUs to the worker.";
      };

      tasksMax = lib.mkOption {
        type = lib.types.ints.positive;
        default = 4096;
        description = "TasksMax of the slice, against fork bombs in job steps.";
      };
    };
    # }}}
  };
  # }}}

  config = lib.mkIf cfg.enable {
    # {{{ Assertions
    assertions = [
      {
        assertion = !config.services.forgejo.enable;
        message = "yomi.forgejoCiWorker must run on a machine of its own, not on the Forgejo host.";
      }
      {
        assertion = !(lib.elem "gitea-runner" trustedUsers || lib.elem "*" trustedUsers);
        message = "yomi.forgejoCiWorker: the job user must not be a nix trusted user (nix.settings.trusted-users).";
      }
      {
        assertion = missingCaches == [] && missingKeys == [];
        message = ''
          yomi.forgejoCiWorker: root's nix.conf lacks caches the untrusted runner relies on.
          Missing substituters: ${toString missingCaches}
          Missing keys: ${toString missingKeys}
        '';
      }
      {
        assertion = lib.all (p: !isStorePath p) ([cfg.tokenFile] ++ cfg.environmentFiles ++ lib.optional (cfg.gitSshKeyFile != null) cfg.gitSshKeyFile);
        message = "yomi.forgejoCiWorker: credential files must not live in the world-readable nix store.";
      }
      {
        assertion = !config.virtualisation.docker.enable && !config.virtualisation.podman.enable;
        message = "yomi.forgejoCiWorker runs host jobs only; a container runtime on the worker would be reachable from them.";
      }
    ];
    # }}}
    # {{{ Runner
    services.gitea-actions-runner.instances.${instance} = {
      enable = true;
      inherit (cfg) name url tokenFile labels hostPackages;
      settings.runner.capacity = 1;
    };

    systemd.services.${unit} = {
      environment =
        {YOMI_CI_HOST_LOCAL_SERVICES = "0";}
        // lib.optionalAttrs (cfg.gitSshKeyFile != null) {
          GIT_SSH_COMMAND = "ssh -i /run/credentials/${unit}.service/${sshKeyCredential} -o IdentitiesOnly=yes";
        };
      serviceConfig = {
        Slice = "${slice}.slice";
        EnvironmentFile = cfg.environmentFiles;
        LoadCredential = lib.optional (cfg.gitSshKeyFile != null) "${sshKeyCredential}:${cfg.gitSshKeyFile}";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        UMask = "0077";
      };
    };
    # }}}
    # {{{ Resources
    nix.settings = {
      max-jobs = cfg.resources.maxJobs;
      inherit (cfg.resources) cores;
    };

    systemd.slices.${slice}.sliceConfig =
      {
        MemoryHigh = cfg.resources.memoryHigh;
        MemoryMax = cfg.resources.memoryMax;
        MemorySwapMax = cfg.resources.memorySwapMax;
        TasksMax = cfg.resources.tasksMax;
      }
      // lib.optionalAttrs (cfg.resources.cpuQuota != null) {CPUQuota = cfg.resources.cpuQuota;};

    # Builds a job requests run as children of the daemon, outside the
    # runner's cgroup. Putting the daemon in the same slice bounds both.
    systemd.services.nix-daemon.serviceConfig.Slice = "${slice}.slice";
    # }}}
  };
}
