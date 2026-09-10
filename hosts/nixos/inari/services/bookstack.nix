{
  config,
  lib,
  ...
}: let
  port = config.yomi.ports.bookstack;
in {
  # {{{ Reverse proxy
  yomi.nginx.at.wiki.port = port;
  # }}}
  # {{{ Secrets
  sops.secrets.bookstack_db_password = {
    sopsFile = ../secrets.yaml;
    owner = "bookstack";
    group = "bookstack";
  };
  sops.secrets.bookstack_app_key = {
    sopsFile = ../secrets.yaml;
    owner = "bookstack";
    group = "bookstack";
  };
  # }}}
  # {{{ Service
  services.bookstack = {
    enable = true;
    hostname = config.yomi.nginx.at.wiki.host;
    poolConfig = {
      "pm" = "dynamic";
      "pm.max_children" = 12;
      "pm.start_servers" = 2;
      "pm.min_spare_servers" = 2;
      "pm.max_spare_servers" = 4;
    };
    settings = {
      APP_URL = config.yomi.nginx.at.wiki.url;
      APP_LANG = "en";
      APP_DEBUG = "false";
      APP_KEY_FILE = config.sops.secrets.bookstack_app_key.path;

      DB_HOST = "/run/postgresql";
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
  # {{{ Postgres
  services.postgresql.ensureDatabases = ["bookstack"];
  services.postgresql.ensureUsers = [
    {
      name = "bookstack";
      ensureDBOwnership = true;
    }
  ];
  # }}}
  # {{{ Storage
  environment.persistence."/persist/state".directories = [
    {
      directory = config.services.bookstack.dataDir;
      mode = "u=rwx,g=,o=";
      user = "bookstack";
      group = "bookstack";
    }
  ];
  # }}}
}
