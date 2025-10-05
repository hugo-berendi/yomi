{config, ...}: {
  # {{{ Secrets
  sops.secrets.immich_secrets = {
    sopsFile = ../secrets.yaml;
    owner = config.services.immich.user;
    group = config.services.immich.group;
  };

  sops.secrets.immich_oauth_client_secret = {
    sopsFile = ../secrets.yaml;
  };
  # }}}
  # {{{ Reverse proxy
  yomi.nginx.at.immich.port = config.yomi.ports.immich;
  yomi.cloudflared.at."share.immich".port = config.yomi.ports.ipp;
  # }}}
  # {{{ Public proxy
  services.immich-public-proxy = {
    enable = true;
    immichUrl = config.yomi.nginx.at.immich.url;
    port = config.yomi.ports.ipp;
  };
  # }}}
  # {{{ Service
  services.immich = {
    enable = true;
    port = config.yomi.ports.immich;
    host = "localhost";
    mediaLocation = "/raid5pool/media/photos";
    secretsFile = config.sops.secrets.immich_secrets.path;
  };
  # }}}
  # {{{ Persistence
  environment.persistence."/persist/state".directories = [
    "/var/lib/immich"
  ];
  # }}}
}
