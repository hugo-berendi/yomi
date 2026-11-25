{
  config,
  inputs,
  ...
}: let
  endpoint = config.yomi.web.at.hugo-berendi-de;
in {
  # {{{ Ports
  yomi.ports = {
    hugo-berendi-de = 8514;
  };
  # }}}
  imports = [inputs.hugo-berendi-de.nixosModules.default];

  # {{{ Reverse proxy
  # The homepage is the zone apex. Anubis and iocaine stay off so link previews
  # and search engines reach it.
  yomi.web.at.hugo-berendi-de = {
    subdomain = "";
    transport = "pangolin";
    authentication = "none";
    pangolin.allowedCountries = [];
  };
  # }}}
  # {{{ Service
  services.hugo-berendi-de = {
    enable = true;
    domain = endpoint.host;
  };

  # The site's module defaults to TLS plus ACME for a directly exposed vhost.
  # The public gateway terminates TLS and connects over loopback, so
  # the vhost must not ask for a certificate or listen on 80/443.
  services.nginx.virtualHosts.${endpoint.host} = {
    forceSSL = false;
    enableACME = false;
    listen = [
      {
        addr = "127.0.0.1";
        inherit (endpoint) port;
      }
    ];
  };
  # }}}
}
