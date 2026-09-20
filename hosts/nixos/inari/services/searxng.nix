{config, ...}: {
  yomi.cloudflared.at.search.port = config.yomi.ports.searxng;
  # {{{ Secrets
  sops.secrets.searxng_env = {
    sopsFile = ../secrets.yaml;
  };
  # }}}
  # {{{ General config
  services.searx = {
    enable = true;
    domain = "search.hugo-berendi.de";
    environmentFile = config.sops.secrets.searxng_env.path;
    settings = {
      use_default_settings = true;
      general = {
        debug = false;
        instance_name = "hugosearch";
      };
      server = {
        port = config.yomi.ports.searxng;
        bind_address = "127.0.0.1";
        secret_key = "$SEARXNG_SECRET_KEY";
      };
      search = {
        formats = ["html" "json"];
      };
      engines = [
        {
          name = "google";
          shortcut = "g";
          engine = "google";
        }
        {
          name = "archwiki";
          shortcut = "aw";
          engine = "archlinux";
        }
        {
          name = "duckduckgo";
          shortcut = "ddg";
          engine = "duckduckgo";
        }
        {
          name = "currency-converter";
          shortcut = "conv";
          engine = "currency_convert";
        }
        {
          name = "duden";
          shortcut = "d";
          engine = "duden";
        }
        {
          name = "github";
          shortcut = "gh";
          engine = "github";
        }
        {
          name = "wikidata";
          disabled = true;
        }
        {
          name = "ahmia";
          disabled = true;
        }
        {
          name = "torch";
          disabled = true;
        }
        {
          name = "yacy images";
          disabled = true;
        }
      ];
    };
  };

  environment.persistence."/persist/state".directories = [
    "/var/lib/searx"
  ];

  systemd.services.searx.serviceConfig =
    {
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateDevices = true;
      PrivateMounts = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      RestrictNamespaces = true;
      RestrictSUIDSGID = true;
      SystemCallArchitectures = "native";
    }
    // {
      ReadWritePaths = ["/var/lib/searx"];
    };
}
