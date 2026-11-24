{config, ...}: {
  # {{{ Ports
  yomi.ports = {
    paperless = 8445;
  };
  # }}}
  # {{{ Reverse proxy
  yomi.web.at.paperless = {
    transport = "nginx";
    authentication = "application";
    monitor.enable = true;
    homepage = {
      group = "Tooling";
      name = "Paperless";
      icon = "paperless.svg";
      description = "Document management";
    };
  };
  # }}}
  # {{{ Secrets
  sops.secrets.paperless_env = {
    sopsFile = ../secrets.yaml;
    owner = config.services.paperless.user;
  };

  sops.secrets.paperless_passwd = {
    sopsFile = ../secrets.yaml;
    owner = config.services.paperless.user;
  };
  # }}}
  # {{{ Service
  services.paperless = {
    enable = true;
    port = config.yomi.ports.paperless;
    address = "127.0.0.1";
    dataDir = "/raid5pool/data/paperless";
    mediaDir = "/raid5pool/media/documents";
    environmentFile = config.sops.secrets.paperless_env.path;
    passwordFile = config.sops.secrets.paperless_passwd.path;
    exporter = {
      enable = true;
    };
    settings = {
      PAPERLESS_AUTO_LOGIN_USERNAME = "admin";
      PAPERLESS_CSRF_TRUSTED_ORIGINS = "https://paperless.hugo-berendi.de";
      # Also limits the tesseract build to these languages (plus equ, osd);
      # stirling-pdf.nix matches the list so both share one tesseract.
      PAPERLESS_OCR_LANGUAGE = "deu+eng";
    };
  };
  # }}}
}
