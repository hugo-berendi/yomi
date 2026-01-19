{
  config,
  lib,
  ...
}: {
  # {{{ Reverse proxy
  yomi.cloudflared.at.pocket-id = {
    port = config.yomi.ports.pocket-id;
    enableAnubis = false;
    subdomain = "auth";
  };
  # }}}
  # {{{ Secrets
  sops.secrets.pocket_id_env = {
    sopsFile = ../secrets.yaml;
    owner = config.services.pocket-id.user;
    group = config.services.pocket-id.group;
  };
  sops.secrets.no_reply_smtp_password = {
    sopsFile = ../secrets.yaml;
    owner = config.services.pocket-id.user;
    group = config.services.pocket-id.group;
  };
  sops.secrets.pocket_id_encription_key = {
    sopsFile = ../secrets.yaml;
    owner = config.services.pocket-id.user;
    group = config.services.pocket-id.group;
  };
  sops.secrets.pocket_id_maxmind_api_key = {
    sopsFile = ../secrets.yaml;
    owner = config.services.pocket-id.user;
    group = config.services.pocket-id.group;
  };
  # }}}
  # {{{ Service
  services.pocket-id = {
    enable = true;
    environmentFile = config.sops.secrets.pocket_id_env.path;
    settings = {
      PORT = config.yomi.cloudflared.at.pocket-id.port;
      TRUST_PROXY = true;
      ANALYTICS_DISABLED = true;

      APP_URL = config.yomi.cloudflared.at.pocket-id.url;
      APP_NAME = "Yomi SSO";

      DB_PROVIDER = "sqlite";

      UI_CONFIG_DISABLED = true;

      ENCRYPTION_KEY_FILE = config.sops.secrets.pocket_id_encription_key.path;

      MAXMIND_LICENSE_KEY_FILE = config.sops.secrets.pocket_id_maxmind_api_key.path;

      ALLOW_USER_SIGNUPS = "withToken";
      SIGNUP_DEFAULT_USER_GROUP_IDS = "[\"7428ce20-1c46-4ac3-8a8c-49e0da0b652a\"]";

      ACCENT_COLOR = "hsl(267deg, 57%, 78%)";

      SMTP_TLS = "tls";
      SMTP_PORT = 465;
      SMTP_HOST = "smtp.migadu.com";
      SMTP_FROM = "no-reply@tengu.hugo-berendi.de";
      SMTP_USER = "no-reply@tengu.hugo-berendi.de";
      SMTP_PASSWORD_FILE = config.sops.secrets.no_reply_smtp_password.path;

      EMAIL_LOGIN_NOTIFICATION_ENABLED = true;
      EMAIL_ONE_TIME_ACCESS_AS_ADMIN_ENABLED = true;
    };
  };

  # }}}
  # {{{ Storage
  environment.persistence."/persist/state".directories = [
    {
      directory = config.services.pocket-id.dataDir;
      mode = "u=rwx,g=,o=";
      user = config.users.users.pocket-id.name;
      group = config.users.users.pocket-id.group;
    }
  ];
  # }}}
  # {{{ Hardening
  systemd.services.pocket-id.serviceConfig =
    config.yomi.hardening.presets.standard
    // {
      ReadWritePaths = [config.services.pocket-id.dataDir];
    };
  # }}}
}
