{
  lib,
  config,
  ...
}: {
  sops.secrets.forgejo_mail_password = {
    sopsFile = ../secrets.yaml;
    owner = config.services.forgejo.user;
    group = config.services.forgejo.group;
  };

  yomi.cloudflared.at.git.port = config.yomi.ports.forgejo;

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

    # See [the cheatsheet](https://docs.gitea.com/next/administration/config-cheat-sheet)
    settings = {
      default.APP_NAME = "moonforge";

      server = {
        DOMAIN = config.yomi.cloudflared.at.git.host;
        HTTP_PORT = config.yomi.cloudflared.at.git.port;
        ROOT_URL = config.yomi.cloudflared.at.git.url;
        LANDING_PAGE = "hugo-berendi"; # Make my profile the landing page
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
}
