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

  # Add CNAME record for ssh access. Unlike the http interface,
  # this will only get exposed over tailscale, so it is safe.
  yomi.dns.records = [
    {
      type = "CNAME";
      zone = config.yomi.dns.domain;
      at = "ssh.git";
      to = config.networking.hostName;
    }
  ];

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
      default.APP_NAME = "hugit";

      server = {
        DOMAIN = config.yomi.cloudflared.at.git.host;
        HTTP_PORT = config.yomi.cloudflared.at.git.port;
        ROOT_URL = config.yomi.cloudflared.at.git.url;
        LANDING_PAGE = "hugo-berendi"; # Make my profile the landing page
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

  # Clean up dumps older than a week.
  # The data is also saved in zfs snapshots and rsync backups,
  # so this is just an extra layer of safety.
  systemd.tmpfiles.rules = ["d ${config.services.forgejo.stateDir}/dump - - - 7d"];
}
