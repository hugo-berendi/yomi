{
  config,
  upkgs,
  ...
}: let
  # Immich's theme.customCss expects space-separated RGB triplets, not hex.
  rgb = color: "${config.lib.stylix.colors."${color}-rgb-r"} ${config.lib.stylix.colors."${color}-rgb-g"} ${config.lib.stylix.colors."${color}-rgb-b"}";
in {
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
  # Single-label subdomain: Cloudflare's free Universal SSL only covers one
  # level of wildcard (*.<domain>), so a nested "share.immich.<domain>" host
  # would have no matching edge certificate on this account.
  yomi.cloudflared.at."immich-share".port = config.yomi.ports.ipp;
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

    # Shared links are generated using this domain, so it must be the public
    # proxy's URL, not the LAN/VPN-only nginx vhost.
    settings.server.externalDomain = config.yomi.cloudflared.at."immich-share".url;

    settings.trash = {
      enabled = true;
      days = 30;
    };

    settings.storageTemplate = {
      enabled = true;
      template = "{{y}}/{{y}}-{{MM}}-{{dd}}/{{filename}}";
    };

    settings.map.enabled = true;
    settings.reverseGeocoding.enabled = true;

    settings.notifications.smtp = {
      enabled = true;
      from = "Immich <no-reply@tengu.hugo-berendi.de>";
      replyTo = "no-reply@tengu.hugo-berendi.de";
      transport = {
        host = "smtp.migadu.com";
        port = 465;
        secure = true;
        username = "no-reply@tengu.hugo-berendi.de";
        password._secret = config.sops.secrets.msmtp_password.path;
      };
    };

    settings.theme.customCss = ''
      :root, .dark {
        --immich-primary: ${rgb "base0D"};
        --immich-dark-primary: ${rgb "base0D"};
        --immich-bg: ${rgb "base00"};
        --immich-dark-bg: ${rgb "base00"};
        --immich-fg: ${rgb "base05"};
        --immich-dark-fg: ${rgb "base05"};
        --immich-gray: ${rgb "base02"};
        --immich-dark-gray: ${rgb "base02"};
      }
    '';
  };

  # }}}
}
