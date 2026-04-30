{
  config,
  lib,
  ...
}: {
  # {{{ Reverse proxy
  yomi.nginx.at.mealie.port = config.yomi.ports.mealie;
  # }}}
  # {{{ Secrets
  sops.templates."mealie.env".content = ''
    SMTP_PASSWORD=${config.sops.placeholder.msmtp_password}
  '';
  # }}}
  # {{{ Service
  services.mealie = {
    enable = true;
    port = config.yomi.ports.mealie;
    listenAddress = "127.0.0.1";
    credentialsFile = config.sops.templates."mealie.env".path;

    database.createLocally = true;

    settings = {
      BASE_URL = config.yomi.nginx.at.mealie.url;
      DEFAULT_LOCALE = "en_US";

      # SMTP Configuration
      SMTP_HOST = "smtp.migadu.com";
      SMTP_PORT = 465;
      SMTP_FROM_NAME = "Mealie";
      SMTP_AUTH_STRATEGY = "SSL";
      SMTP_FROM_EMAIL = "no-reply@tengu.hugo-berendi.de";
      SMTP_USER = "no-reply@tengu.hugo-berendi.de";
    };
  };
  # }}}
  # {{{ Hardening
  systemd.services.mealie.serviceConfig = config.yomi.hardening.presets.standard;
  # }}}
}
