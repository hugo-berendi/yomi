{
  config,
  lib,
  pkgs,
  ...
}: let
  host = "wiki.hugo-berendi.de";
  mysqlInitScript = pkgs.writeShellScript "bookstack-mysql-init" ''
    set -euo pipefail
    PW="$(< "$CREDENTIALS_DIRECTORY/db_password")"
    "${lib.getExe' pkgs.mariadb "mysql"}" -u root <<SQL
    CREATE USER IF NOT EXISTS 'bookstack'@'localhost' IDENTIFIED BY '$PW';
    GRANT ALL PRIVILEGES ON bookstack.* TO 'bookstack'@'localhost';
    FLUSH PRIVILEGES;
    SQL
  '';
in {
  # {{{ Reverse proxy (handled by the bookstack module itself)
  yomi.dns.records = lib.singleton {
    type = "CNAME";
    zone = "hugo-berendi.de";
    at = "wiki";
    to = config.networking.hostName;
  };
  # }}}
  # {{{ Secrets
  sops.secrets.bookstack_app_key = {
    sopsFile = ../secrets.yaml;
    owner = "bookstack";
    group = "nginx";
  };
  sops.secrets.bookstack_db_password = {
    sopsFile = ../secrets.yaml;
    owner = "bookstack";
    group = "nginx";
  };
  # }}}
  # {{{ MySQL - BookStack only supports MySQL/MariaDB (no postgres, no sqlite)
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    ensureDatabases = ["bookstack"];
    ensureUsers = lib.singleton {
      name = "bookstack";
      ensurePermissions = {"bookstack.*" = "ALL PRIVILEGES";};
    };
  };
  environment.persistence."/persist/state".directories = lib.singleton {
    directory = "/var/lib/mysql";
    mode = "u=rwx,g=,o=";
    user = "mysql";
    group = "mysql";
  };
  systemd.services.bookstack-mysql-init = {
    description = "Configure bookstack MySQL user password";
    after = ["mysql.service"];
    requires = ["mysql.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "mysql";
      Group = "mysql";
      LoadCredential = "db_password:${config.sops.secrets.bookstack_db_password.path}";
      ExecStart = mysqlInitScript;
    };
    wantedBy = ["multi-user.target"];
  };
  systemd.services.bookstack-setup = {
    after = ["bookstack-mysql-init.service"];
    requires = ["bookstack-mysql-init.service"];
    serviceConfig.SupplementaryGroups = ["smtp"];
  };
  # }}}
  # {{{ Service
  services.bookstack = {
    enable = true;
    hostname = host;
    nginx = {
      forceSSL = true;
      enableACME = true;
    };
    poolConfig = {
      "pm" = "dynamic";
      "pm.max_children" = 12;
      "pm.start_servers" = 2;
      "pm.min_spare_servers" = 2;
      "pm.max_spare_servers" = 4;
    };
    settings = {
      APP_URL = "https://${host}";
      APP_LANG = "en";
      APP_DEBUG = "false";
      APP_KEY_FILE = config.sops.secrets.bookstack_app_key.path;

      DB_HOST = "localhost";
      DB_DATABASE = "bookstack";
      DB_USERNAME = "bookstack";
      DB_PASSWORD_FILE = config.sops.secrets.bookstack_db_password.path;

      MAIL_DRIVER = "smtp";
      MAIL_FROM_NAME = "BookStack";
      MAIL_FROM = "no-reply@tengu.hugo-berendi.de";
      MAIL_HOST = "smtp.migadu.com";
      MAIL_PORT = "465";
      MAIL_USERNAME = "no-reply@tengu.hugo-berendi.de";
      MAIL_PASSWORD_FILE = config.sops.secrets.no_reply_smtp_password.path;
      MAIL_ENCRYPTION = "ssl";
    };
  };
  # }}}
  # {{{ Storage
  environment.persistence."/persist/state".directories = lib.singleton {
    directory = config.services.bookstack.dataDir;
    mode = "u=rwx,g=,o=";
    user = "bookstack";
    group = "nginx";
  };

  users.groups.smtp = {};
  users.groups.nginx.members = ["bookstack"];
  users.users.bookstack.extraGroups = ["smtp"];
  systemd.services.phpfpm-bookstack.serviceConfig.SupplementaryGroups = ["smtp"];
  # }}}
}
