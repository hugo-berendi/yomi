{
  config,
  pkgs,
  ...
}: {
  environment.systemPackages = [pkgs.cloudflared];
  # {{{ Secrets
  sops.secrets.cloudflare_tunnel_credentials = {
    sopsFile = ../secrets.yaml;
  };
  # }}}
  # {{{ Service
  yomi.cloudflared.tunnel = "39befb96-2f47-44c1-a748-a5516e0891ca";
  services.cloudflared = {
    enable = true;
    tunnels.${config.yomi.cloudflared.tunnel} = {
      credentialsFile = config.sops.secrets.cloudflare_tunnel_credentials.path;
      default = "http_status:404";
    };
  };
  # }}}
}
