{
  config,
  upkgs,
  ...
}: {
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
  yomi.nginx.at.immich = {
    port = config.yomi.ports.immich;
    clientMaxBodySize = "50000M";
  };
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
    # 26.05's immich (2.7.5) is EOL and marked insecure (CVE-2026-59258,
    # CVE-2026-82272); 3.x only ships from nixpkgs-unstable until 26.11.
    package = upkgs.immich;
    port = config.yomi.ports.immich;
    host = "127.0.0.1";
    mediaLocation = "/raid5pool/media/photos";
    secretsFile = config.sops.secrets.immich_secrets.path;

    settings.backup.database.keepLastAmount = 60;

    settings.oauth = {
      enabled = true;
      issuerUrl = config.yomi.cloudflared.at.pocket-id.url;
      clientId = "adf23559-7783-4b2e-bab4-443da5844e18";
      autoRegister = true;
      scope = "openid profile email";
      buttonText = "Login with Pocket ID";
      clientSecret._secret =
        config.sops.secrets.immich_oauth_client_secret.path;
    };

    settings.server.externalDomain = config.yomi.nginx.at.immich.url;
  };

  # }}}
}
