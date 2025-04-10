{config, ...}: {
  yomi.nginx.at.paperless.port = config.yomi.ports.paperless;

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

  services.paperless = {
    enable = true;
    port = config.yomi.ports.paperless;
    address = "0.0.0.0";
    dataDir = "/raid5pool/data/paperless";
    mediaDir = "/raid5pool/media/documents";
    environmentFile = config.sops.secrets.paperless_env.path;
    passwordFile = config.sops.secrets.paperless_passwd.path;
    exporter = {
      enable = true;
    };
    settings = {};
  };
}
