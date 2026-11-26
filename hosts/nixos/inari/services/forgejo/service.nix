{
  lib,
  config,
  pkgs,
  ...
}: let
  endpoint = config.yomi.web.at.git;
  runnerEnabled = config.yomi.forgejo.productionRunner.enable;
in {
  # {{{ Options
  options.yomi.forgejo.productionRunner.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Run the Actions runner on inari itself. Turn this off only after a
      dedicated worker (yomi.forgejoCiWorker on its own machine) has picked up
      jobs for the `native` label. Off removes the runner unit, its sops
      secrets and templates, its persisted state directory and its nix trust
      from the evaluated system. It does not delete the runner's registration
      in Forgejo, nor the old state under /persist/state/var/lib/gitea-runner.
    '';
  };
  # }}}

  config = lib.mkMerge [
    {
      # {{{ Ports
      yomi.ports = {
        forgejo = 8409;
      };
      # }}}
    }
    {
      # {{{ Secrets
      sops.secrets.forgejo_mail_password = {
        sopsFile = ../../secrets.yaml;
        owner = config.services.forgejo.user;
        group = config.services.forgejo.group;
      };
      # }}}
      # {{{ Reverse proxy
      yomi.web.at.git = {
        port = config.yomi.ports.forgejo;
        transport = "pangolin";
        authentication = "application";
        enableAnubis = true;
        monitor.enable = true;
      };
      # }}}
      # {{{ DNS records
      yomi.dns.records = [
        {
          type = "CNAME";
          zone = config.yomi.dns.domain;
          at = "ssh.git";
          to = config.networking.hostName;
        }
      ];

      # Forgejo does not run its own sshd (START_SSH_SERVER is unset), so git
      # traffic to this name is served by the host's sshd and presents the host
      # key. Pin it under that name too, or every clone is trust-on-first-use.
      yomi.ssh.extraHostNames = ["ssh.${endpoint.host}"];
      # }}}
      # {{{ Service
      services.forgejo = {
        enable = true;
        stateDir = "/persist/state/var/lib/forgejo";
        secrets.mailer = {
          PASSWD = config.sops.secrets.forgejo_mail_password.path;
        };

        dump = {
          enable = true;
          type = "tar.gz";
        };

        lfs.enable = true;

        settings = {
          default.APP_NAME = "hugit";

          server = {
            DOMAIN = endpoint.host;
            HTTP_PORT = endpoint.port;
            ROOT_URL = endpoint.url;
            LANDING_PAGE = "hugo-berendi";
            SSH_DOMAIN = "ssh.${endpoint.host}";
          };

          cron.ENABLED = true;
          service.DISABLE_REGISTRATION = true;
          session.COOKIE_SECURE = true;

          mailer = {
            ENABLED = true;
            SMTP_PORT = 465;
            SMTP_ADDR = "smtp.migadu.com";
            USER = "git@tengu.hugo-berendi.de";
          };

          repository = {
            DISABLE_STARS = true;
            DISABLED_REPO_UNITS = "";
            # Every repo gets issues and pull requests from the start. With only
            # repo.code, T3 Code's issue list got HTTP 404 from each new repo.
            DEFAULT_REPO_UNITS = lib.strings.concatStringsSep "," [
              "repo.code"
              "repo.issues"
              "repo.pulls"
            ];
          };
        };
      };

      systemd.tmpfiles.rules = ["d ${config.services.forgejo.stateDir}/dump - - - 7d"];

      systemd.services.forgejo.serviceConfig = {
        ReadWritePaths = [config.services.forgejo.stateDir];
      };
      # }}}
      # {{{ Actions runner
      # The user outlives the runner: t3code-repair.nix hands its socket to this
      # user, and with the runner off nothing runs as it.
      users.users.gitea-runner = {
        isSystemUser = true;
        group = "gitea-runner";
      };

      users.groups.gitea-runner = {};

      # The runner is trusted so nix honours the flake's extra-trusted-public-keys
      # (a restricted setting) instead of warning that it is not a trusted user.
      # Root's nix.conf already lists the same keys (common/caches.nix), which is
      # why the dedicated worker does without this.
      nix.settings.trusted-users = ["root" "hugob"] ++ lib.optional runnerEnabled "gitea-runner";
    }
    (lib.mkIf runnerEnabled {
      services.gitea-actions-runner.instances.default = {
        enable = true;
        name = "inari-runner";
        url = "http://localhost:${toString config.yomi.ports.forgejo}";
        tokenFile = config.sops.templates."forgejo_runner_token.env".path;
        labels = ["native:host"];
        hostPackages = with pkgs; [
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
        settings = {
          # Parallel flake evaluations exhausted RAM and zram beside the GPU model.
          runner.capacity = 1;
        };
      };

      systemd.services.gitea-runner-default.serviceConfig =
        {
          NoNewPrivileges = true;
          Slice = "nix-builds.slice";
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          # Bound host-job evaluators together. Builds dispatched to nix-daemon
          # run outside this cgroup and are not covered by these limits.
          MemoryHigh = "8G";
          MemoryMax = "12G";
          MemorySwapMax = "2G";
        }
        // {PrivateDevices = lib.mkForce false;}
        // {
          DynamicUser = lib.mkForce false;
          User = "gitea-runner";
          Group = "gitea-runner";
          ReadWritePaths = ["/var/lib/gitea-runner"];
          EnvironmentFile = [config.sops.templates."gitea_runner_nix.env".path];
        };

      # Read-only deploy key for the "skills" flake input, which is fetched over
      # ssh:// (git-ssh serving is the host's own sshd, see yomi.ssh.extraHostNames
      # above). git has no ssh client of its own, so `ssh` had to be added to
      # hostPackages too, or `nix flake update` fails with "cannot run ssh".
      systemd.services.gitea-runner-default.environment.GIT_SSH_COMMAND = "ssh -i ${config.sops.secrets.gitea_runner_skills_deploy_key.path} -o IdentitiesOnly=yes";

      sops.secrets.forgejo_runner_token = {
        sopsFile = ../../secrets.yaml;
        owner = "gitea-runner";
        group = "gitea-runner";
      };

      sops.secrets.gitea_runner_skills_deploy_key = {
        sopsFile = ../../secrets.yaml;
        owner = "gitea-runner";
        group = "gitea-runner";
      };

      # Scoped to no permissions, only good for raising nix's github: input
      # resolution off the 60/hr anonymous rate limit that api.github.com
      # applies per source IP -- inari's shared address hits that fast.
      sops.secrets.gitea_runner_github_token = {
        sopsFile = ../../secrets.yaml;
        owner = "gitea-runner";
        group = "gitea-runner";
      };

      sops.templates."forgejo_runner_token.env" = {
        content = ''
          TOKEN=${config.sops.placeholder.forgejo_runner_token}
        '';
        owner = "gitea-runner";
        group = "gitea-runner";
      };

      sops.templates."gitea_runner_nix.env" = {
        content = ''
          NIX_CONFIG=access-tokens = github.com=${config.sops.placeholder.gitea_runner_github_token}
        '';
        owner = "gitea-runner";
        group = "gitea-runner";
      };

      yomi.persistence.at.state.apps.gitea-runner.directories = [
        {
          directory = "/var/lib/gitea-runner";
          user = "gitea-runner";
          group = "gitea-runner";
        }
      ];
    })
    # }}}
  ];
}
