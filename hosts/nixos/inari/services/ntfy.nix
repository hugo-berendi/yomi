{
  config,
  lib,
  ...
}: let
  port = config.yomi.ports.ntfy;
in {
  # {{{ Reverse proxy
  yomi.cloudflared.at.ntfy = {
    inherit port;
    enableAnubis = false;
  };
  # }}}
  # {{{ Service
  services.ntfy-sh = {
    enable = true;
    settings = {
      listen-http = "127.0.0.1:${toString port}";
      base-url = config.yomi.cloudflared.at.ntfy.url;
      behind-proxy = true;

      cache-file = "/var/lib/ntfy-sh/cache.db";
      attachment-cache-dir = "/var/lib/ntfy-sh/attachments";

      # {{{ SMTP for outgoing email notifications
      smtp-sender-addr = "smtp.migadu.com:465";
      smtp-sender-from = "no-reply@tengu.hugo-berendi.de";
      smtp-sender-user = "no-reply@tengu.hugo-berendi.de";
      smtp-sender-pass = "\${NTFY_SMTP_PASSWORD}";
      # }}}

      # {{{ Enable polling/Auth via file
      auth-default-access = "deny-all";
      enable-signup = false;
      enable-login = true;
      # }}}
    };

    environmentFile = config.sops.secrets.ntfy_env.path;
  };
  # }}}
  # {{{ Secrets
  sops.secrets.ntfy_env = {
    sopsFile = ../secrets.yaml;
    owner = config.users.users.ntfy-sh.name;
    group = config.users.users.ntfy-sh.group;
  };
  # }}}
  # {{{ Storage
  environment.persistence."/persist/state".directories = [
    {
      directory = "/var/lib/ntfy-sh";
      mode = "u=rwx,g=,o=";
      user = config.users.users.ntfy-sh.name;
      group = config.users.users.ntfy-sh.group;
    }
  ];
  # }}}
  # {{{ Hardening
  systemd.services.ntfy-sh.serviceConfig = lib.mkMerge [
    {
      ProtectSystem = lib.mkForce "strict";
      ProtectHome = true;
      PrivateMounts = true;
      ProtectClock = true;
      SystemCallArchitectures = "native";
    }
    {
      DynamicUser = lib.mkForce false;
      User = config.users.users.ntfy-sh.name;
      Group = config.users.users.ntfy-sh.group;
      StateDirectory = lib.mkForce "ntfy-sh";
      ReadWritePaths = ["/var/lib/ntfy-sh"];
    }
  ];
  # }}}
}
