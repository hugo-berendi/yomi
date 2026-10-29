{config, ...}: let
  port = config.yomi.ports.homepage;
in {
  sops.secrets.homepage_env = {
    sopsFile = ../secrets.yaml;
  };

  yomi.nginx.at.lab.port = port;

  services.homepage-dashboard = {
    enable = true;
    listenPort = port;
    environmentFiles = [config.sops.secrets.homepage_env.path];

    settings = {
      title = "✨ The celestial citadel ✨";
      headerStyle = "clean";
      color = "slate";
      layout = {
        Infrastructure = {
          style = "row";
          columns = 3;
        };
        Tooling = {
          style = "row";
          columns = 3;
        };
        Media = {
          style = "row";
          columns = 4;
        };
        Entertainment = {
          style = "row";
          columns = 3;
        };
      };
    };

    customCSS = with config.lib.stylix.colors.withHashtag; ''
      body {
      	background-color: ${base00};
      	color: ${base05};
      }
      .service-card {
      	background-color: ${base01};
      	border-color: ${base03};
      }
      .service-card:hover {
      	background-color: ${base02};
      	border-color: ${base0D};
      }
      h1, h2, h3, h4, h5, h6 {
      	color: ${base0D};
      }
    '';

    services = [
      {
        Infrastructure = [
          {
            Prometheus = {
              icon = "prometheus.svg";
              href = "https://prometheus.hugo-berendi.de";
              description = "Monitoring system";
              widget = {
                type = "prometheus";
                url = "http://127.0.0.1:${toString config.yomi.ports.prometheus}";
              };
            };
          }
          {
            Grafana = {
              icon = "grafana.svg";
              href = "https://grafana.hugo-berendi.de";
              description = "Pretty dashboards :3";
              widget = {
                type = "grafana";
                url = "http://127.0.0.1:${toString config.yomi.ports.grafana}";
                username = "{{HOMEPAGE_VAR_GRAFANA_USERNAME}}";
                password = "{{HOMEPAGE_VAR_GRAFANA_PASSWORD}}";
                version = 2;
              };
            };
          }
          {
            Syncthing = {
              icon = "syncthing.svg";
              href = "https://syncthing.lapetus.hugo-berendi.de";
              description = "File synchronization";
            };
          }
          {
            Tailscale = {
              icon = "tailscale.svg";
              href = "https://tailscale.com/";
              description = "Access this homelab from anywhere";
            };
          }
          {
            "Pocket ID" = {
              icon = "mdi-fingerprint";
              href = "https://pocket-id.hugo-berendi.de";
              description = "Passkey authentication & OIDC";
            };
          }
          {
            Gatus = {
              icon = "gatus.svg";
              href = "https://status.hugo-berendi.de";
              description = "Service status monitoring";
              widget = {
                type = "gatus";
                url = "http://127.0.0.1:${toString config.yomi.ports.gatus}";
              };
            };
          }
          {
            Ntfy = {
              icon = "ntfy.svg";
              href = "https://ntfy.hugo-berendi.de";
              description = "Push notifications hub";
            };
          }
          {
            Scrutiny = {
              icon = "scrutiny.svg";
              href = "https://scrutiny.hugo-berendi.de";
              description = "SMART / disk health dashboard";
              widget = {
                type = "scrutiny";
                url = "http://127.0.0.1:${toString config.yomi.ports.scrutiny}";
              };
            };
          }
          {
            Healthchecks = {
              icon = "healthchecks.svg";
              href = "https://ping.hugo-berendi.de";
              description = "Cron heartbeat monitor";
            };
          }
          {
            "Adguard Home" = {
              icon = "adguard-home.svg";
              href = "https://adguard.hugo-berendi.de";
              description = "DNS filtering";
              widget = {
                type = "adguard";
                url = "http://127.0.0.1:${toString config.yomi.ports.adguard}";
              };
            };
          }
          {
            Cloudflare = {
              icon = "cloudflare.svg";
              href = "https://dash.cloudflare.com/761d3e81b3e42551e33c4b73274ecc82/hugo-berendi.de/";
              description = "Domain management";
            };
          }
          {
            Beszel = {
              icon = "mdi-chart-areaspline";
              href = "https://monitoring.hugo-berendi.de";
              description = "Server metrics";
            };
          }
        ];
      }
      {
        Tooling = [
          {
            Mealie = {
              icon = "mealie.svg";
              href = config.yomi.nginx.at.mealie.url;
              description = "Recipes and meal planning";
            };
          }
          {
            "Changedetection.io" = {
              icon = "changedetection-io.svg";
              href = config.yomi.nginx.at.changedetection.url;
              description = "Website change monitoring";
            };
          }
          {
            "Stirling PDF" = {
              icon = "stirling-pdf.svg";
              href = config.yomi.nginx.at.pdf.url;
              description = "PDF tools";
            };
          }
          {
            "Paperless AI" = {
              icon = "paperless.svg";
              href = config.yomi.nginx.at.paperless-ai.url;
              description = "Document processing assistant";
            };
          }
          {
            "T3 Code" = {
              icon = "mdi-code-braces";
              href = config.yomi.nginx.at.t3code.url;
              description = "Coding agent workspace";
            };
          }
          {
            OpenCode = {
              icon = "mdi-console";
              href = config.yomi.nginx.at.code.url;
              description = "Coding agent workspace";
            };
          }
          {
            Diabetes = {
              icon = "mdi-chart-line";
              href = config.yomi.nginx.at.diabetes.url;
              description = "Glucose reports";
            };
          }
          {
            Vaultwarden = {
              icon = "bitwarden.svg";
              href = "https://warden.hugo-berendi.de";
              description = "Password manager";
            };
          }
          {
            SearXNG = {
              icon = "searxng.svg";
              href = "https://search.hugo-berendi.de";
              description = "Search engine";
            };
          }
          {
            Radicale = {
              icon = "radicale.svg";
              href = "https://cal.hugo-berendi.de";
              description = "Calendar server";
            };
          }
          {
            Microbin = {
              icon = "microbin.svg";
              href = "https://bin.hugo-berendi.de";
              description = "Code & file sharing";
            };
          }
          {
            Forgejo = {
              icon = "forgejo.svg";
              href = "https://git.hugo-berendi.de";
              description = "Git forge";
            };
          }
          {
            Paperless = {
              icon = "paperless.svg";
              href = "https://paperless.hugo-berendi.de";
              description = "Document management";
            };
          }
          {
            N8N = {
              icon = "n8n.svg";
              href = "https://n8n.hugo-berendi.de";
              description = "Workflow automation";
            };
          }
          {
            Nextcloud = {
              icon = "nextcloud.svg";
              href = "https://cloud.hugo-berendi.de";
              description = "Cloud storage";
            };
          }
          {
            SimpleLogin = {
              icon = "mdi-email-fast-outline";
              href = "https://app.simplelogin.io";
              description = "Email aliasing";
            };
          }
          {
            "Home Assistant" = {
              icon = "home-assistant.svg";
              href = "https://home.hugo-berendi.de";
              description = "Home automation";
              widget = {
                type = "homeassistant";
                url = "http://127.0.0.1:${toString config.yomi.ports.home-assistant}";
                key = "{{HOMEPAGE_VAR_HOMEASSISTANT_API_KEY}}";
              };
            };
          }
          {
            Immich = {
              icon = "immich.svg";
              href = "https://immich.hugo-berendi.de";
              description = "Photo management";
              widget = {
                type = "immich";
                url = "http://127.0.0.1:${toString config.yomi.ports.immich}";
                key = "{{HOMEPAGE_VAR_IMMICH_API_KEY}}";
                version = 2;
              };
            };
          }
          {
            Karakeep = {
              icon = "si-hoarder";
              href = "https://karakeep.hugo-berendi.de";
              description = "Bookmark manager";
            };
          }
          {
            Miniflux = {
              icon = "miniflux.svg";
              href = config.yomi.cloudflared.at.miniflux.url;
              description = "Minimal RSS reader";
            };
          }
        ];
      }
      {
        Media = [
          {
            Jellyfin = {
              icon = "jellyfin.svg";
              href = "https://media.hugo-berendi.de";
              description = "Media server";
              widget = {
                type = "jellyfin";
                url = "http://127.0.0.1:${toString config.yomi.ports.jellyfin}";
                key = "{{HOMEPAGE_VAR_JELLYFIN_API_KEY}}";
                enableBlocks = true;
                enableNowPlaying = true;
              };
            };
          }
          {
            Suwayomi = {
              icon = "mdi-book-open-page-variant";
              href = "https://suwayomi.hugo-berendi.de";
              description = "Comic server";
            };
          }
          {
            Audiobookshelf = {
              icon = "audiobookshelf.svg";
              href = "https://audiobookshelf.hugo-berendi.de";
              description = "Audiobook and podcast server";
            };
          }
          {
            Seerr = {
              icon = "jellyseerr.svg";
              href = "https://request-media.hugo-berendi.de";
              description = "Media requests";
              widget = {
                type = "jellyseerr";
                url = "http://127.0.0.1:${toString config.yomi.ports.jellyseerr}";
                key = "{{HOMEPAGE_VAR_JELLYSEERR_API_KEY}}";
              };
            };
          }
          {
            Transmission = {
              icon = "transmission.svg";
              href = "https://torrent.hugo-berendi.de";
              description = "Torrent client";
              widget = {
                type = "transmission";
                url = "https://torrent.hugo-berendi.de";
                rpcUrl = config.nixarr.transmission.extraSettings."rpc-url";
              };
            };
          }
          {
            Radarr = {
              icon = "radarr.svg";
              href = "https://radarr.hugo-berendi.de";
              description = "Movie management";
              widget = {
                type = "radarr";
                url = "http://127.0.0.1:${toString config.yomi.ports.radarr}";
                key = "{{HOMEPAGE_VAR_RADARR_API_KEY}}";
                enableQueue = true;
              };
            };
          }
          {
            Sonarr = {
              icon = "sonarr.svg";
              href = "https://sonarr.hugo-berendi.de";
              description = "TV show management";
              widget = {
                type = "sonarr";
                url = "http://127.0.0.1:${toString config.yomi.ports.sonarr}";
                key = "{{HOMEPAGE_VAR_SONARR_API_KEY}}";
                enableQueue = true;
              };
            };
          }
          {
            Lidarr = {
              icon = "lidarr.svg";
              href = "https://lidarr.hugo-berendi.de";
              description = "Music management";
              widget = {
                type = "lidarr";
                url = "http://127.0.0.1:${toString config.yomi.ports.lidarr}";
                key = "{{HOMEPAGE_VAR_LIDARR_API_KEY}}";
                enableQueue = true;
              };
            };
          }
          {
            Readarr = {
              icon = "readarr.svg";
              href = "https://readarr.hugo-berendi.de";
              description = "Book management";
              widget = {
                type = "readarr";
                url = "http://127.0.0.1:${toString config.yomi.ports.readarr}";
                key = "{{HOMEPAGE_VAR_READARR_API_KEY}}";
                enableQueue = true;
              };
            };
          }
          {
            Bazarr = {
              icon = "bazarr.svg";
              href = "https://bazarr.hugo-berendi.de";
              description = "Subtitle management";
              widget = {
                type = "bazarr";
                url = "http://127.0.0.1:${toString config.yomi.ports.bazarr}";
                key = "{{HOMEPAGE_VAR_BAZARR_API_KEY}}";
                enableQueue = true;
              };
            };
          }
          {
            Prowlarr = {
              icon = "prowlarr.svg";
              href = "https://prowlarr.hugo-berendi.de";
              description = "Indexer manager";
              widget = {
                type = "prowlarr";
                url = "http://127.0.0.1:${toString config.yomi.ports.prowlarr}";
                key = "{{HOMEPAGE_VAR_PROWLARR_API_KEY}}";
                enableQueue = true;
              };
            };
          }
        ];
      }
      {
        Entertainment = [
          {
            Invidious = {
              icon = "invidious.svg";
              href = "https://yt.hugo-berendi.de";
              description = "Youtube client";
            };
          }
          {
            Pelican = {
              icon = "mdi-feather";
              href = "https://pelican.hugo-berendi.de";
              description = "Game server panel";
            };
          }
          {
            Sable = {
              icon = "mdi-chat-processing-outline";
              href = "https://sable.hugo-berendi.de";
              description = "Matrix web client";
            };
          }
        ];
      }
    ];

    bookmarks = [
      {
        Development = [
          {
            Github = [
              {
                abbr = "GH";
                href = "https://github.com/hugo-berendi/yomi";
              }
            ];
          }
        ];
      }
    ];

    widgets = [
      {
        resources = {
          cpu = true;
          memory = true;
          disk = "/";
          uptime = true;
        };
      }
      {
        datetime = {
          text_size = "xl";
          format = {
            dateStyle = "long";
            timeStyle = "short";
            hour12 = false;
          };
        };
      }
      {
        openmeteo = {
          label = "Feldkirchen-Westerham";
          latitude = 47.9167;
          longitude = 11.9167;
          units = "metric";
          cache = 5;
        };
      }
      {
        greeting = {
          text_size = "xl";
          text = "Welcome to the celestial citadel";
        };
      }
    ];
  };
}
