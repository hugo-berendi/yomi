{
  config,
  pkgs,
  ...
}: {
  sops.secrets.authentik_env = {
    sopsFile = ../secrets.yaml;
  };
  yomi.cloudflared.at.authentik.port = config.yomi.ports.authentik;
  services.authentik = {
    enable = true;
    # The environmentFile needs to be on the target host!
    # Best use something like sops-nix or agenix to manage it
    environmentFile = config.sops.secrets.authentik_env.path;
    settings = {
      email = {
        host = "smtp.migadu.com";
        port = 465;
        username = "authentik@tengu.hugo-berendi.de";
        use_tls = true;
        use_ssl = false;
        from = "authentik@tengu.hugo-berendi.de";
      };
      disable_startup_analytics = true;
      avatars = "initials";
    };
  };
}
