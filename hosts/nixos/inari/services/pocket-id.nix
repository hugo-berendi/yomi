{
  config,
  lib,
  ...
}: {
  # {{{ Reverse proxy
  yomi.cloudflared.at.pocket-id.port = config.yomi.ports.pocket-id;
  # }}}
  # {{{ Secrets
  sops.secrets.pocket_id_env = {
    sopsFile = ../secrets.yaml;
  };
  # }}}
  # {{{ Service
  services.pocket-id = {
    enable = true;
    environmentFile = config.sops.secrets.pocket_id_env.path;
    settings = {
      ANALYTICS_DISABLED = true;
      APP_URL = "https://pocket-id.hugo-berendi.de";
      TRUST_PROXY = true;
    };
  };

  # }}}
}
