{
  config,
  pkgs,
  ...
}: {
  # {{{ Service
  services.ddclient = {
    enable = false;
    interval = "1m";
    configFile = config.sops.templates."ddclient.conf".path;

    package = pkgs.ddclient.overrideAttrs (_: {
      src = pkgs.fetchFromGitHub {
        owner = "ddclient";
        repo = "ddclient";
        rev = "9885d55a3741363ad52d3463cb846d5782efb073";
        sha256 = "0zyi8h13y18vrlxavx1vva4v0ya5v08bxdxlr3is49in3maz2n37";
      };
    });
  };
  # }}}
  # {{{ Configuration
  sops.templates."ddclient.conf".content = ''
    cache=/var/lib/ddclient/ddclient.cache
    foreground=YES

    use=web, web=checkip.dyndns.com/, web-skip='Current IP Address: '

    protocol=cloudflare
    apikey=${config.sops.placeholder.porkbun_api_key}
    secretapikey=${config.sops.placeholder.porkbun_secret_api_key}
    root-domain=hugo-berendi.de
    node1.pelican.hugo-berendi.de
  '';
  # }}}
}
