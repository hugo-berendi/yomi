{config, ...}: {
  sops.secrets.cloudflare_tunnel_credentials = {
    sopsFile = ../secrets.yaml;
    owner = config.services.cloudflared.user;
    group = config.services.cloudflared.group;
  };

  yomi.cloudflared.tunnel = "347d9ead-a523-4f8b-bca7-3066e31e2952";
  services.cloudflared = {
    enable = true;
    tunnels.${config.yomi.cloudflared.tunnel} = {
      credentialsFile = config.sops.secrets.cloudflare_tunnel_credentials.path;
      default = "http_status:404";
    };
  };
}
