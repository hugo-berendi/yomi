{config, ...}: {
  # {{{ reverse proxy
  yomi.cloudflared.at.keycloak.port = config.yomi.ports.keycloak;
  # }}}
  # {{{ Secrets
  sops.secrets.kc_database = {
    sopsFile = ../secrets.yaml;
  };
  # }}}
  services.keycloak = {
    enable = true;
    initialAdminPassword = "admin";
    settings = {
      hostname = "keycloak.hugo-berendi.de";
      hostname-backchannel-dynamic = true;
      http-port = config.yomi.cloudflared.at.keycloak.port;
    };
    database = {
      passwordFile = config.sops.secrets.kc_database.path;
    };
  };
}
