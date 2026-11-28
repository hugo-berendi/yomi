{
  config,
  lib,
  ...
}: let
  port = config.yomi.ports.healthchecks;
  endpoint = config.yomi.web.at.ping;
in {
  # {{{ Ports
  yomi.ports = {
    healthchecks = 8497;
  };
  # }}}
  # {{{ Reverse proxy
  yomi.web.at.ping = {
    inherit port;
    transport = "pangolin";
    authentication = "application";
  };
  # }}}
  # {{{ Service
  services.healthchecks = {
    enable = true;
    listenAddress = "127.0.0.1";
    inherit port;

    settings = {
      SITE_ROOT = endpoint.url;
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
    {name = "grafana";}
  ];
  # }}}
  # {{{ Secrets
  sops.secrets.healthchecks_secret_key = {
    sopsFile = ../../secrets.yaml;
    owner = config.users.users.healthchecks.name;
    group = config.users.users.healthchecks.group;
  };
  # }}}
  # Grafana authenticates as its own Unix user and can query only the two
  # reporting views. Ping URLs, payloads and project credentials stay private.
  systemd.services.healthchecks-grafana-views = {
    description = "Expose read-only Healthchecks views to Grafana";
    wantedBy = ["multi-user.target"];
    after = ["healthchecks-migration.service" "postgresql-setup.service"];
    requires = ["healthchecks-migration.service" "postgresql-setup.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = config.users.users.healthchecks.name;
      ProtectSystem = "strict";
      ProtectHome = true;
      NoNewPrivileges = true;
      ExecStart = "${config.services.postgresql.package}/bin/psql --no-psqlrc --host=/run/postgresql --dbname=healthchecks --set=ON_ERROR_STOP=1 --file=${./grafana-views.sql}";
    };
  };
  services.grafana.provision.datasources.settings.datasources = [
    {
      name = "Healthchecks";
      uid = "yomi-healthchecks-db";
      type = "postgres";
      access = "proxy";
      url = "/run/postgresql";
      user = "grafana";
      jsonData = {
        database = "healthchecks";
        sslmode = "disable";
        maxOpenConns = 2;
        maxIdleConns = 2;
      };
    }
  ];
  # {{{ Storage
  yomi.persistence.at.state.apps.healthchecks.directories = [
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
