{config, ...}: {
  sops.secrets.cloudflare_tunnel_credentials = {
    sopsFile = ../secrets.yaml;
    owner = config.services.cloudflared.user;
    group = config.services.cloudflared.group;
  };

  yomi.cloudflared.tunnel = "bacb68ec-218f-4135-9e88-888b366ac83e";
  services.cloudflared = {
    enable = true;
    tunnels.${config.yomi.cloudflared.tunnel} = {
      credentialsFile = config.sops.secrets.cloudflare_tunnel_credentials.path;
      default = "http_status:404";
    };
  };
}
