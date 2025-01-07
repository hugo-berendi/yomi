{config, ...}: {
  yomi.cloudflared.at.jellyseerr.port = config.yomi.ports.jellyseerr;
  services.authentik = {
    enable = true;
    # The environmentFile needs to be on the target host!
    # Best use something like sops-nix or agenix to manage it
    environmentFile = "/run/secrets/authentik/authentik-env";
    settings = {
      email = {
        host = "smtp.example.com";
        port = 587;
        username = "authentik@example.com";
        use_tls = true;
        use_ssl = false;
        from = "authentik@example.com";
      };
      disable_startup_analytics = true;
      avatars = "initials";
    };
  };
}
