{config, ...}: {
  # {{{ reverse proxy / domain setup
  yomi.cloudflared.at.authentik.port = config.yomi.ports.authentik;
  # }}}
  # {{{ Secrets
  sops.secrets.authentik_env = {
    sopsFile = ../secrets.yaml;
    # owner = config.users.users.authentik.name;
    # group = config.users.users.authentik.group;
  };
  # }}}
  # {{{ General config
  services.authentik = {
    enable = false;
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
}
