{
  lib,
  config,
  ...
}: {
  # {{{ Secrets
  sops.secrets.forgejo_mail_password = {
    sopsFile = ../secrets.yaml;
    owner = config.services.forgejo.user;
    group = config.services.forgejo.group;
  };
  # }}}
  # {{{ Reverse proxy
  yomi.cloudflared.at.git = {
    port = config.yomi.ports.forgejo;
    enableAnubis = true;
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
        DOMAIN = config.yomi.cloudflared.at.git.host;
        HTTP_PORT = config.yomi.cloudflared.at.git.port;
        ROOT_URL = config.yomi.cloudflared.at.git.url;
        LANDING_PAGE = "hugo-berendi";
        SSH_DOMAIN = "ssh.${config.yomi.cloudflared.at.git.host}";
      };

      cron.ENABLED = true;
      service.DISABLE_REGISTRATION = false;
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
        DEFAULT_REPO_UNITS = lib.strings.concatStringsSep "," [
          "repo.code"
        ];
      };
    };
  };

  systemd.tmpfiles.rules = ["d ${config.services.forgejo.stateDir}/dump - - - 7d"];
  # }}}
  # {{{ Actions runner
  users.users.gitea-runner = {
    isSystemUser = true;
    group = "gitea-runner";
  };

  users.groups.gitea-runner = {};

  services.gitea-actions-runner = {
    instances.default = {
      enable = true;
      name = "inari-runner";
      url = "http://localhost:${toString config.yomi.ports.forgejo}";
      tokenFile = config.sops.templates."forgejo_runner_token.env".path;
      labels = [
        "nix:docker://nixos/nix:latest"
        "ubuntu-latest:docker://node:20-bullseye"
      ];
      settings = {
        runner.capacity = 2;
      };
    };
  };

  systemd.services.gitea-runner-default.serviceConfig.DynamicUser = lib.mkForce false;

  sops.secrets.forgejo_runner_token = {
    sopsFile = ../secrets.yaml;
    owner = "gitea-runner";
    group = "gitea-runner";
  };

  sops.templates."forgejo_runner_token.env".content = ''
    TOKEN=${config.sops.placeholder.forgejo_runner_token}
  '';

  sops.templates."forgejo_runner_token.env".owner = "gitea-runner";
  sops.templates."forgejo_runner_token.env".group = "gitea-runner";

  environment.persistence."/persist/state".directories = [
    {
      directory = "/var/lib/gitea-runner";
      user = "gitea-runner";
      group = "gitea-runner";
    }
  ];
  # }}}
}
