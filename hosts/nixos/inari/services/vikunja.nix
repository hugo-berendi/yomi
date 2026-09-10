{
  config,
  lib,
  ...
}: let
  port = config.yomi.ports.vikunja;
in {
  # {{{ Reverse proxy
  yomi.cloudflared.at.vikunja = {
    inherit port;
    enableAnubis = false;
  };
  # }}}
  # {{{ Service
  services.vikunja = {
    enable = true;
    address = "127.0.0.1";
    port = port;
    frontendHostname = config.yomi.cloudflared.at.vikunja.host;
    frontendScheme = "https";

    database = {
      type = "postgres";
      host = "/run/postgresql";
      user = "vikunja";
      database = "vikunja";
    };

    environmentFiles = [config.sops.secrets.vikunja_env.path];

    settings = {
      # {{{ SMTP via no-reply
      mailer = {
        enabled = true;
        host = "smtp.migadu.com";
        port = 465;
        authtype = "login";
        username = "no-reply@tengu.hugo-berendi.de";
        fromemail = "no-reply@tengu.hugo-berendi.de";
        queuelength = "100";
        queuetimeout = "30";
      };
      # }}}

      files.maxsize = "262144000";

      # {{{ OIDC via Pocket ID
      auth = {
        local.enabled = true;
        openid = {
          enabled = true;
          providers.pocketid = {
            name = "Pocket ID";
            authurl = config.yomi.cloudflared.at.pocket-id.url;
            clientid = "vikunja";
            scope = "openid profile email";
          };
        };
      };
      # }}}
    };
  };
  # }}}
  # {{{ Postgres
  services.postgresql.ensureDatabases = ["vikunja"];
  services.postgresql.ensureUsers = [
    {
      name = "vikunja";
      ensureDBOwnership = true;
    }
  ];
  # }}}
  # {{{ Secrets
  sops.secrets.vikunja_env = {
    sopsFile = ../secrets.yaml;
    owner = "vikunja";
    group = "vikunja";
  };
  # }}}
  # {{{ User/Group - upstream uses DynamicUser; we want a stable UID for persistence + sops chown
  users.groups.vikunja = {};
  users.users.vikunja = {
    isSystemUser = true;
    group = "vikunja";
    home = "/var/lib/vikunja";
  };
  # {{{ Hardening
  systemd.services.vikunja.serviceConfig = lib.mkMerge [
    (lib.mapAttrs (_: lib.mkForce) config.yomi.hardening.presets.standard)
    config.yomi.hardening.overrides.network
    {
      DynamicUser = lib.mkForce false;
      User = "vikunja";
      Group = "vikunja";
    }
  ];
  # }}}
}
