{
  config,
  lib,
  ...
}: let
  port = config.yomi.ports.miniflux;
in {
  # {{{ Reverse proxy
  yomi.cloudflared.at.miniflux = {
    inherit port;
    enableAnubis = false;
  };
  # }}}
  # {{{ Service
  services.miniflux = {
    enable = true;
    createDatabaseLocally = true;
    adminCredentialsFile = config.sops.secrets.miniflux_admin.path;
    config = {
      LISTEN_ADDR = "127.0.0.1:${toString port}";
      BASE_URL = config.yomi.cloudflared.at.miniflux.url;

      # {{{ SMTP via no-reply
      SMTP = "true";
      SMTP_HOST = "smtp.migadu.com";
      SMTP_PORT = 465;
      SMTP_USERNAME = "no-reply@tengu.hugo-berendi.de";
      SMTP_FROM = "no-reply@tengu.hugo-berendi.de";
      SMTP_PASSWORD_FILE = config.sops.secrets.no_reply_smtp_password.path;
      # }}}

      HTTPS = "true";
      DOMAIN = config.yomi.cloudflared.at.miniflux.host;

      # {{{ Maintenance
      CLEANUP_ARCHIVE_READ_DAYS = "120";
      CLEANUP_REMOVE_SESSIONS_DAYS = "30";
      # }}}

      POLLING_SCHEDULER = "entry_frequency";
      POLLING_FREQUENCY = "30";
      BATCH_SIZE = "100";
    };
  };
  # }}}
  # {{{ Secrets
  sops.secrets.miniflux_admin = {
    sopsFile = ../secrets.yaml;
    owner = "miniflux";
    group = "miniflux";
  };
  # }}}
  # {{{ User/Group - upstream uses DynamicUser; we want a stable UID for sops chown (admin creds file is read as root anyway, but sops-nix assigns the file owner)
  users.groups.miniflux = {};
  users.users.miniflux = {
    isSystemUser = true;
    group = "miniflux";
    home = "/var/lib/miniflux";
  };

  users.groups.smtp = {};
  users.users.miniflux.extraGroups = ["smtp"];
  # {{{ Hardening
  systemd.services.miniflux.serviceConfig = lib.mkMerge [
    (lib.mapAttrs (_: lib.mkForce) config.yomi.hardening.presets.strict)
    config.yomi.hardening.overrides.network
    {
      DynamicUser = lib.mkForce false;
      User = "miniflux";
      Group = "miniflux";
      SupplementaryGroups = ["smtp"];
    }
  ];
  # }}}
}
