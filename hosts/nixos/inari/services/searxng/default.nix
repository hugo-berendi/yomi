{
  config,
  upkgs,
  ...
}: let
  vpn = config.vpnNamespaces.wg;
in {
  imports = [./theme.nix];

  yomi.cloudflared.at.search = {
    port = config.yomi.ports.searxng;
    proxyAddress = vpn.namespaceAddress;
  };
  # {{{ Secrets
  sops.secrets.searxng_env = {
    sopsFile = ../../secrets.yaml;
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
      # Brave answered every query with a 429 or a page the scraper could not
      # parse. Removing it takes it out of preferences and bangs, not just
      # the default set.
      use_default_settings.engines.remove = [
        "brave"
        "brave.images"
        "brave.videos"
        "brave.news"
        "braveapi"
      ];
      general = {
        debug = false;
        instance_name = "hugosearch";
      };
      server = {
        port = config.yomi.ports.searxng;
        bind_address = vpn.namespaceAddress;
        secret_key = "$SEARXNG_SECRET_KEY";
        # Fixes the scheme and host in generated links (opensearch.xml, RSS)
        # instead of trusting whatever headers came through the tunnel.
        base_url = "https://${config.services.searx.domain}/";
      };
      search = {
        formats = ["html" "json"];
        # Upstream's default autocompleter is DuckDuckGo, which sends one
        # request from this IP per keystroke to the engine that CAPTCHAs it
        # the most.
        autocomplete = "wikipedia";
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

  # {{{ VPN
  # DuckDuckGo CAPTCHAs this line's Vodafone IP on every request, even a
  # bare curl, and a CAPTCHA never suspends the engine, so each search
  # re-offends. The nixarr WireGuard exit got a 200 from the same request
  # on 2026-09-29. The whole service has to move: a namespace is per
  # process, and SearXNG cannot send one engine through a different route.
  #
  # It is killswitched like transmission: if the tunnel is down, searx has
  # no route out, rather than falling back to the home IP.
  systemd.services.searx.vpnConfinement = {
    enable = true;
    vpnNamespace = "wg";
  };
  vpnNamespaces.wg.portMappings = [
    {
      from = config.yomi.ports.searxng;
      to = config.yomi.ports.searxng;
      protocol = "tcp";
    }
  ];
  # }}}

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
      # SearXNG exits if its startup network check fails, and upstream sets
      # Restart=no, so one bad moment in the tunnel left search down until
      # someone noticed. (The first outage was DNS misrouted out of the
      # namespace, see media/vpn.nix; retrying did not fix that, but it does
      # cover a tunnel that is merely slow or briefly down.)
      Restart = "on-failure";
      RestartSec = "10s";
    };
}
