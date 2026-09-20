{
  config,
  lib,
  ...
}: let
  port = config.yomi.ports.healthchecks;
in {
  # {{{ Reverse proxy
  yomi.cloudflared.at.ping = {
    subdomain = "ping";
    inherit port;
    enableAnubis = false;
  };
  # }}}
  # {{{ Service
  services.healthchecks = {
    enable = true;
    listenAddress = "127.0.0.1";
    inherit port;

    settings = {
      SITE_ROOT = config.yomi.cloudflared.at.ping.url;
      SITE_NAME = "Yomi Ping";
      REGISTRATION_OPEN = false;
      SECRET_KEY_FILE = config.sops.secrets.healthchecks_secret_key.path;
      DEBUG = false;

      # {{{ Local no-reply SMTP relay
      EMAIL_HOST = "smtp.migadu.com";
      EMAIL_PORT = "465";
      EMAIL_HOST_USER = "no-reply@tengu.hugo-berendi.de";
      EMAIL_HOST_PASSWORD_FILE = config.sops.secrets.no_reply_smtp_password.path;
      EMAIL_USE_SSL = "True";
      DEFAULT_FROM_EMAIL = "no-reply@tengu.hugo-berendi.de";
      # }}}

      # {{{ Database
      DB = "postgres";
      DB_NAME = "healthchecks";
      DB_USER = "healthchecks";
      DB_HOST = "/run/postgresql";
      # }}}
    };
  };
  # }}}
  # {{{ Postgres
  services.postgresql.ensureDatabases = ["healthchecks"];
  services.postgresql.ensureUsers = [
    {
      name = "healthchecks";
      ensureDBOwnership = true;
    }
  ];
  # }}}
  # {{{ Secrets
  sops.secrets.healthchecks_secret_key = {
    sopsFile = ../secrets.yaml;
    owner = config.users.users.healthchecks.name;
    group = config.users.users.healthchecks.group;
  };
  # }}}
  # {{{ Storage
  environment.persistence."/persist/state".directories = [
    {
      directory = config.services.healthchecks.dataDir;
      mode = "u=rwx,g=,o=";
      user = config.users.users.healthchecks.name;
      group = config.users.users.healthchecks.group;
    }
  ];

  users.groups.smtp = {};
  users.users.healthchecks.extraGroups = ["smtp"];

  systemd.services.healthchecks.serviceConfig = lib.mkMerge [
    {
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateDevices = true;
      PrivateMounts = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      RestrictNamespaces = true;
      RestrictSUIDSGID = true;
      SystemCallArchitectures = "native";
    }
    {
      PrivateNetwork = lib.mkForce false;
      RestrictAddressFamilies = lib.mkForce ["AF_INET" "AF_INET6" "AF_UNIX" "AF_NETLINK"];
    }
    {
      ReadWritePaths = [config.services.healthchecks.dataDir];
      SupplementaryGroups = ["smtp"];
    }
  ];
  # }}}
}
