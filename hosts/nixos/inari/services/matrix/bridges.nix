{
  config,
  lib,
  ...
}: let
  matrixHost = "matrix.${config.yomi.dns.domain}";
  matrixUrl = "http://127.0.0.1:${toString config.yomi.ports.matrix-tuwunel}";
  adminMxid = "@${config.yomi.pilot.name}:${matrixHost}";

  basePermissions = {
    "*" = "relay";
    "${matrixHost}" = "user";
    "${adminMxid}" = "admin";
    "@kamachi:${matrixHost}" = "user";
  };
in {
  # {{{ Secrets
  sops.templates = {
    "mautrix-whatsapp.env" = {
      content = ''
        MAUTRIX_WHATSAPP_APPSERVICE_AS_TOKEN=${config.sops.placeholder.matrix_tuwunel_appservice_whatsapp_as_token}
        MAUTRIX_WHATSAPP_APPSERVICE_HS_TOKEN=${config.sops.placeholder.matrix_tuwunel_appservice_whatsapp_hs_token}
      '';
      owner = config.users.users.mautrix-whatsapp.name;
      group = config.users.groups.mautrix-whatsapp.name;
    };

    "mautrix-signal.env" = {
      content = ''
        MAUTRIX_SIGNAL_APPSERVICE_AS_TOKEN=${config.sops.placeholder.matrix_tuwunel_appservice_signal_as_token}
        MAUTRIX_SIGNAL_APPSERVICE_HS_TOKEN=${config.sops.placeholder.matrix_tuwunel_appservice_signal_hs_token}
      '';
      owner = config.users.users.mautrix-signal.name;
      group = config.users.groups.mautrix-signal.name;
    };

    "mautrix-discord.env" = {
      content = ''
        MAUTRIX_DISCORD_APPSERVICE_AS_TOKEN=${config.sops.placeholder.matrix_tuwunel_appservice_discord_as_token}
        MAUTRIX_DISCORD_APPSERVICE_HS_TOKEN=${config.sops.placeholder.matrix_tuwunel_appservice_discord_hs_token}
      '';
      owner = config.users.users.mautrix-discord.name;
      group = config.users.groups.mautrix-discord.name;
    };
  };
  # }}}

  # {{{ Mautrix WhatsApp
  services.mautrix-whatsapp = {
    enable = true;
    registerToSynapse = false;
    serviceDependencies = ["tuwunel.service"];
    environmentFile = config.sops.templates."mautrix-whatsapp.env".path;

    settings = {
      homeserver = {
        address = matrixUrl;
        domain = matrixHost;
      };

      appservice = {
        as_token = "$MAUTRIX_WHATSAPP_APPSERVICE_AS_TOKEN";
        hs_token = "$MAUTRIX_WHATSAPP_APPSERVICE_HS_TOKEN";
      };

      bridge.permissions = basePermissions;
    };
  };
  # }}}

  # {{{ Mautrix Signal
  services.mautrix-signal = {
    enable = true;
    registerToSynapse = false;
    serviceDependencies = ["tuwunel.service"];
    environmentFile = config.sops.templates."mautrix-signal.env".path;

    settings = {
      homeserver = {
        address = matrixUrl;
        domain = matrixHost;
      };

      appservice = {
        as_token = "$MAUTRIX_SIGNAL_APPSERVICE_AS_TOKEN";
        hs_token = "$MAUTRIX_SIGNAL_APPSERVICE_HS_TOKEN";
      };

      bridge.permissions = basePermissions;
    };
  };
  # }}}

  # {{{ Mautrix Discord
  services.mautrix-discord = {
    enable = true;
    registerToSynapse = false;
    serviceDependencies = ["tuwunel.service"];
    environmentFile = config.sops.templates."mautrix-discord.env".path;

    settings = {
      homeserver = {
        address = matrixUrl;
        domain = matrixHost;
      };

      appservice = {
        id = "discord";
        address = "http://127.0.0.1:29334";
        hostname = "127.0.0.1";
        port = 29334;
        as_token = "$MAUTRIX_DISCORD_APPSERVICE_AS_TOKEN";
        hs_token = "$MAUTRIX_DISCORD_APPSERVICE_HS_TOKEN";
        database = {
          type = "sqlite3-fk-wal";
          uri = "file:/var/lib/mautrix-discord/mautrix-discord.db?_txlock=immediate";
        };
      };

      bridge.permissions = basePermissions;
    };
  };
  # }}}

  # {{{ Mautrix Discord Fixes
  systemd.services.mautrix-discord-registration = {
    wantedBy = ["multi-user.target"];
    before = ["mautrix-discord.service"];
  };
  systemd.services.mautrix-discord = {
    wants = ["mautrix-discord-registration.service"];
    after = ["mautrix-discord-registration.service"];
  };

  systemd.services.mautrix-whatsapp.preStart = lib.mkBefore ''
    cat > /var/lib/mautrix-whatsapp/whatsapp-registration.yaml <<IN_EOF
    as_token: "$MAUTRIX_WHATSAPP_APPSERVICE_AS_TOKEN"
    hs_token: "$MAUTRIX_WHATSAPP_APPSERVICE_HS_TOKEN"
    id: whatsapp
    url: http://127.0.0.1:29318
    sender_localpart: whatsappbot
    namespaces:
      users:
        - exclusive: true
          regex: '@whatsapp_.*:matrix.${config.yomi.dns.domain}'
        - exclusive: true
          regex: '@whatsappbot:matrix.${config.yomi.dns.domain}'
    IN_EOF
  '';

  systemd.services.mautrix-signal.preStart = lib.mkBefore ''
    cat > /var/lib/mautrix-signal/signal-registration.yaml <<IN_EOF
    as_token: "$MAUTRIX_SIGNAL_APPSERVICE_AS_TOKEN"
    hs_token: "$MAUTRIX_SIGNAL_APPSERVICE_HS_TOKEN"
    id: signal
    url: http://127.0.0.1:29328
    sender_localpart: signalbot
    namespaces:
      users:
        - exclusive: true
          regex: '@signal_.*:matrix.${config.yomi.dns.domain}'
        - exclusive: true
          regex: '@signalbot:matrix.${config.yomi.dns.domain}'
    IN_EOF
  '';
  # }}}
}
