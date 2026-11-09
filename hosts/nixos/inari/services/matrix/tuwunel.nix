{
  config,
  lib,
  upkgs,
  ...
}: let
  matrixHost = "matrix.${config.yomi.dns.domain}";
  bridges = config.yomi.matrix.bridges.enable;
  secret = {
    sopsFile = ../../secrets.yaml;
    owner = config.services.matrix-tuwunel.user;
    group = config.services.matrix-tuwunel.group;
  };
  appserviceTokens = lib.concatMap (bridge: ["matrix_tuwunel_appservice_${bridge}_as_token" "matrix_tuwunel_appservice_${bridge}_hs_token"]) ["whatsapp" "signal" "discord"];
in {
  # {{{ Reverse proxy
  yomi.cloudflared.at.matrix.port = config.yomi.ports.matrix-tuwunel-proxy;
  # }}}

  # {{{ Secrets
  sops.secrets = lib.mkMerge [
    {
      matrix_tuwunel_registration_token = secret;
    }
    # The appservice tokens stay encrypted in secrets.yaml while the bridges are
    # disabled; only their decryption and the Tuwunel registration depend on it.
    (lib.mkIf bridges (lib.genAttrs appserviceTokens (_: secret)))
  ];

  sops.templates = lib.mkIf bridges {
    "tuwunel-appservices.toml" = {
      content = ''
        [global.appservice.whatsapp]
        url = "http://127.0.0.1:29318"
        as_token = "${config.sops.placeholder.matrix_tuwunel_appservice_whatsapp_as_token}"
        hs_token = "${config.sops.placeholder.matrix_tuwunel_appservice_whatsapp_hs_token}"
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
        as_token = "${config.sops.placeholder.matrix_tuwunel_appservice_signal_as_token}"
        hs_token = "${config.sops.placeholder.matrix_tuwunel_appservice_signal_hs_token}"
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
        as_token = "${config.sops.placeholder.matrix_tuwunel_appservice_discord_as_token}"
        hs_token = "${config.sops.placeholder.matrix_tuwunel_appservice_discord_hs_token}"
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
      ip_range_denylist = [
        "10.0.0.0/8"
        "172.16.0.0/12"
        "192.168.0.0/16"
        "100.64.0.0/10"
        "169.254.0.0/16"
        "::1/128"
        "fe80::/10"
        "fc00::/7"
      ];
      trusted_servers = [
        "matrix.org"
        "constellatory.net"
        "tchncs.de"
      ];
    };
  };

  # Without the bridges the upstream ExecStart applies unchanged, so Tuwunel
  # reads no appservice file that no longer exists.
  systemd.services.tuwunel.serviceConfig.ExecStart = lib.mkIf bridges (lib.mkForce ''
    ${lib.getExe config.services.matrix-tuwunel.package} \
      --config "$TUWUNEL_CONFIG" \
      --config "${config.sops.templates."tuwunel-appservices.toml".path}"
  '');
  systemd.services.tuwunel.restartTriggers = lib.mkIf bridges [config.sops.templates."tuwunel-appservices.toml".path];
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
  yomi.persistence.at.state.apps.tuwunel.directories = [
    {
      directory = "/var/lib/${config.services.matrix-tuwunel.stateDirectory}";
      user = config.services.matrix-tuwunel.user;
      group = config.services.matrix-tuwunel.group;
    }
  ];
  # }}}
}
