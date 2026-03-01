{config, ...}: let
  matrixHost = "matrix.${config.yomi.dns.domain}";
  matrixUrl = "http://127.0.0.1:${toString config.yomi.ports.matrix-tuwunel}";
  adminMxid = "@${config.yomi.pilot.name}:${matrixHost}";

  basePermissions = {
    "*" = "relay";
    "${config.yomi.dns.domain}" = "user";
    "${adminMxid}" = "admin";
  };
in {
  # {{{ Secrets
  sops.templates = {
    "mautrix-whatsapp.env" = {
      content = ''
        MAUTRIX_WHATSAPP_APPSERVICE_AS_TOKEN=${config.sops.placeholder.matrix_tuwunel_registration_token}
        MAUTRIX_WHATSAPP_APPSERVICE_HS_TOKEN=${config.sops.placeholder.matrix_tuwunel_registration_token}
      '';
      owner = config.users.users.mautrix-whatsapp.name;
      group = config.users.groups.mautrix-whatsapp.name;
    };

    "mautrix-signal.env" = {
      content = ''
        MAUTRIX_SIGNAL_APPSERVICE_AS_TOKEN=${config.sops.placeholder.matrix_tuwunel_registration_token}
        MAUTRIX_SIGNAL_APPSERVICE_HS_TOKEN=${config.sops.placeholder.matrix_tuwunel_registration_token}
      '';
      owner = config.users.users.mautrix-signal.name;
      group = config.users.groups.mautrix-signal.name;
    };

    "mautrix-discord.env" = {
      content = ''
        MAUTRIX_DISCORD_APPSERVICE_AS_TOKEN=${config.sops.placeholder.matrix_tuwunel_registration_token}
        MAUTRIX_DISCORD_APPSERVICE_HS_TOKEN=${config.sops.placeholder.matrix_tuwunel_registration_token}
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
      };

      bridge.permissions = basePermissions;
    };
  };
  # }}}
}
