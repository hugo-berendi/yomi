{
  config,
  inputs,
  ...
}: let
  tunnel = config.yomi.cloudflared.at.hugo-berendi-de;
in {
  imports = [inputs.hugo-berendi-de.nixosModules.default];

  # {{{ Reverse proxy
  # The homepage is the zone apex. Anubis and iocaine stay off so link previews
  # and search engines reach it.
  yomi.cloudflared.at.hugo-berendi-de = {
    subdomain = "";
    port = config.yomi.ports.hugo-berendi-de;
  };
  # }}}
  # {{{ Service
  services.hugo-berendi-de = {
    enable = true;
    domain = tunnel.host;
  };

  # The site's module defaults to TLS plus ACME for a directly exposed vhost.
  # Here Cloudflare terminates TLS and the tunnel connects over loopback, so
  # the vhost must not ask for a certificate or listen on 80/443.
  services.nginx.virtualHosts.${tunnel.host} = {
    forceSSL = false;
    enableACME = false;
    listen = [
      {
        addr = "127.0.0.1";
        inherit (tunnel) port;
      }
    ];
  };
  # }}}
}
