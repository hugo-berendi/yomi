{config, ...}: {
  # {{{ Reverse proxy
  yomi.cloudflared.at.authentik.port = config.yomi.ports.authentik;
  # }}}
  # {{{ Secrets
  sops.secrets.authentik_env = {
    sopsFile = ../secrets.yaml;
  };
  # }}}
  # {{{ Service
  services.authentik = {
    enable = true;
    environmentFile = config.sops.secrets.authentik_env.path;
    settings = {
      email = {
        host = "smtp.migadu.com";
        port = 587;
        username = "authentik@tengu.hugo-berendi.de";
        use_tls = true;
        use_ssl = false;
        from = "authentik@tengu.hugo-berendi.de";
      };
      disable_startup_analytics = true;
      avatars = "initials";
    };
  };
  # }}}
  # {{{ Persistence
  environment.persistence."/persist/state".directories = [
    "/var/lib/authentik"
  ];
  # }}}
}
