{
  config,
  upkgs,
  ...
}: {
  yomi.cloudflared.at.search.port = config.yomi.ports.searxng;
  # {{{ Secrets
  sops.secrets.searxng_env = {
    sopsFile = ../secrets.yaml;
  };
  # }}}
  # {{{ General config
  services.searx = {
    enable = true;
    # SearXNG's engines are scrapers and rot as the sites change. 26.05's
    # 2026-05-16 snapshot returned nothing for a plain search by 2026-09-29:
    # Google came back empty with no error and Startpage hit a CAPTCHA. Run
    # side by side with the same settings, unstable's 2026-09-22 build
    # returned results from both.
    #
    # Keep this on unstable; a release snapshot goes stale within months.
    package = upkgs.searxng;
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
      # Entries override the upstream engine with the same `name`. Any other
      # name adds a second copy of the engine, and that copy has no traits, so
      # the old "archwiki" entry failed with KeyError 'wiki_netloc'.
      engines = [
        {
          # Upstream now ships google disabled.
          name = "google";
          shortcut = "g";
          disabled = false;
        }
        {
          # The wiki sits behind a bot wall, so the scraper only ever sees
          # the challenge page. It returns nothing, just slowly.
          name = "arch linux wiki";
          disabled = true;
        }
        {
          name = "duckduckgo";
          shortcut = "ddg";
        }
        {
          # Wants ISO codes in capitals: "10 USD to EUR".
          name = "currency";
          shortcut = "conv";
        }
        {
          # Upstream ships duden disabled.
          name = "duden";
          shortcut = "d";
          disabled = false;
        }
        {
          name = "wikidata";
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
