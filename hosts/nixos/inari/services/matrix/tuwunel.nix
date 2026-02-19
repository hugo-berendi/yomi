{
  config,
  lib,
  upkgs,
  ...
}: let
  matrixHost = "matrix.${config.yomi.dns.domain}";
in {
  # {{{ Reverse proxy
  yomi.cloudflared.at.matrix.port = config.yomi.ports.matrix-tuwunel-proxy;
  # }}}

  # {{{ Secrets
  sops.secrets.matrix_tuwunel_registration_token = {
    sopsFile = ../../secrets.yaml;
    owner = config.services.matrix-tuwunel.user;
    group = config.services.matrix-tuwunel.group;
  };
  # }}}

  # {{{ Service
  services.matrix-tuwunel = {
    enable = true;
    package = upkgs.matrix-tuwunel;

    settings.global = {
      server_name = matrixHost;
      address = ["127.0.0.1"];
      port = [config.yomi.ports.matrix-tuwunel];
      allow_federation = true;
      allow_registration = true;
      registration_token_file = config.sops.secrets.matrix_tuwunel_registration_token.path;
      trusted_servers = [
        "matrix.org"
        "constellatory.net"
        "tchncs.de"
      ];
    };
  };
  # }}}

  # {{{ Nginx
  services.nginx.virtualHosts.${matrixHost} = {
    listen = [
      {
        addr = "127.0.0.1";
        port = config.yomi.cloudflared.at.matrix.port;
        ssl = false;
      }
    ];

    locations."= /.well-known/matrix/server".extraConfig = ''
      default_type application/json;
      return 200 '{"m.server":"${matrixHost}:443"}';
    '';

    locations."= /.well-known/matrix/client".extraConfig = ''
      default_type application/json;
      return 200 '{"m.homeserver":{"base_url":"https://${matrixHost}"}}';
    '';

    locations."/_matrix" = {
      proxyPass = "http://127.0.0.1:${toString config.yomi.ports.matrix-tuwunel}";
      proxyWebsockets = true;
    };

    locations."/_synapse" = {
      proxyPass = "http://127.0.0.1:${toString config.yomi.ports.matrix-tuwunel}";
      proxyWebsockets = true;
    };
  };
  # }}}

  # {{{ Persistence
  # HACK: https://github.com/nix-community/impermanence/issues/254
  systemd.services.tuwunel.serviceConfig.DynamicUser = lib.mkForce false;
  environment.persistence."/persist/state".directories = [
    {
      directory = "/var/lib/${config.services.matrix-tuwunel.stateDirectory}";
      user = config.services.matrix-tuwunel.user;
      group = config.services.matrix-tuwunel.group;
    }
  ];
  # }}}
}
