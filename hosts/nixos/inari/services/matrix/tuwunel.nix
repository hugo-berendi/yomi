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

  sops.templates."tuwunel-appservices.toml" = {
    content = ''
      [global.appservice.whatsapp]
      url = "http://127.0.0.1:29318"
      as_token = "${config.sops.placeholder.matrix_tuwunel_registration_token}"
      hs_token = "${config.sops.placeholder.matrix_tuwunel_registration_token}"
      sender_localpart = "whatsappbot"
      rate_limited = false
      receive_ephemeral = false

      [[global.appservice.whatsapp.users]]
      exclusive = true
      regex = "@whatsapp_.*:${matrixHost}"

      [[global.appservice.whatsapp.users]]
      exclusive = true
      regex = "@whatsappbot:${matrixHost}"

      [global.appservice.signal]
      url = "http://127.0.0.1:29328"
      as_token = "${config.sops.placeholder.matrix_tuwunel_registration_token}"
      hs_token = "${config.sops.placeholder.matrix_tuwunel_registration_token}"
      sender_localpart = "signalbot"
      rate_limited = false
      receive_ephemeral = false

      [[global.appservice.signal.users]]
      exclusive = true
      regex = "@signal_.*:${matrixHost}"

      [[global.appservice.signal.users]]
      exclusive = true
      regex = "@signalbot:${matrixHost}"

      [global.appservice.discord]
      url = "http://127.0.0.1:29334"
      as_token = "${config.sops.placeholder.matrix_tuwunel_registration_token}"
      hs_token = "${config.sops.placeholder.matrix_tuwunel_registration_token}"
      sender_localpart = "discordbot"
      rate_limited = false
      receive_ephemeral = true

      [[global.appservice.discord.users]]
      exclusive = true
      regex = "@discord_.*:${matrixHost}"

      [[global.appservice.discord.users]]
      exclusive = true
      regex = "@discordbot:${matrixHost}"
    '';
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

  systemd.services.tuwunel = {
    serviceConfig.ExecStart = lib.mkForce ''
      ${lib.getExe config.services.matrix-tuwunel.package} \
        --config "$TUWUNEL_CONFIG" \
        --config "${config.sops.templates."tuwunel-appservices.toml".path}"
    '';
    restartTriggers = [config.sops.templates."tuwunel-appservices.toml".path];
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
      add_header Access-Control-Allow-Origin * always;
      default_type application/json;
      return 200 '{"m.server":"${matrixHost}:443"}';
    '';

    locations."= /.well-known/matrix/client".extraConfig = ''
      add_header Access-Control-Allow-Origin * always;
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
