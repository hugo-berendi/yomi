{
  pkgs,
  config,
  lib,
  ...
}: let
  port = config.yomi.ports.homepage or 8082;
in {
  sops.secrets.homepage_env = {
    sopsFile = ../secrets.yaml;
  };

  yomi.nginx.at.lab.port = port;

  services.homepage-dashboard = {
    enable = true;
    listenPort = port;
    environmentFile = config.sops.secrets.homepage_env.path;

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
                url = "https://prometheus.hugo-berendi.de";
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
                url = "https://grafana.hugo-berendi.de";
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
            Authentik = {
              icon = "authentik.svg";
              href = "https://authentik.hugo-berendi.de";
              description = "OAuth, OIDC, SSO and more";
              widget = {
                type = "authentik";
                url = "https://authentik.hugo-berendi.de";
                key = "{{HOMEPAGE_VAR_AUTHENTIK_API_KEY}}";
                version = 2;
              };
            };
          }
          {
            "Uptime Kuma" = {
              icon = "uptime-kuma.svg";
              href = "https://uptime.hugo-berendi.de";
              description = "Service status monitoring";
              widget = {
                type = "uptimekuma";
                url = "https://uptime.hugo-berendi.de";
                slug = "{{HOMEPAGE_VAR_UPTIMEKUMA_SLUG}}";
              };
            };
          }
          {
            "Adguard Home" = {
              icon = "adguard-home.svg";
              href = "https://adguard.hugo-berendi.de";
              description = "DNS filtering";
              widget = {
                type = "adguard";
                url = "https://adguard.hugo-berendi.de";
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
        ];
      }
      {
        Tooling = [
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
            Jupyterhub = {
              icon = "jupyter.svg";
              href = "https://jupyter.hugo-berendi.de";
              description = "Notebook collaboration suite";
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
            Owncloud = {
              icon = "owncloud.svg";
              href = "https://cloud.hugo-berendi.de";
              description = "Cloud storage";
            };
          }
          {
            Actual = {
              icon = "actual.svg";
              href = "https://actual.hugo-berendi.de";
              description = "Budget management";
            };
          }
          {
            Anonaddy = {
              icon = "anonaddy.svg";
              href = "https://alias.hugo-berendi.de";
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
                url = "https://home.hugo-berendi.de";
                key = "{{HOMEPAGE_VAR_HOMEASSISTANT_API_KEY}}";
              };
            };
          }
          {
            Guacamole = {
              icon = "guacamole.svg";
              href = "https://guacamole.hugo-berendi.de";
              description = "Remote desktop gateway";
            };
          }
          {
            Immich = {
              icon = "immich.svg";
              href = "https://immich.hugo-berendi.de";
              description = "Photo management";
              widget = {
                type = "immich";
                url = "https://immich.hugo-berendi.de";
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
                url = "https://media.hugo-berendi.de";
                key = "{{HOMEPAGE_VAR_JELLYFIN_API_KEY}}";
                enableBlocks = true;
                enableNowPlaying = true;
              };
            };
          }
          {
            Navidrome = {
              icon = "navidrome.svg";
              href = "https://navidrome.hugo-berendi.de";
              description = "Music server";
              widget = {
                type = "navidrome";
                url = "https://navidrome.hugo-berendi.de";
                user = "{{HOMEPAGE_VAR_NAVIDROME_USER}}";
                token = "{{HOMEPAGE_VAR_NAVIDROME_TOKEN}}";
                salt = "{{HOMEPAGE_VAR_NAVIDROME_SALT}}";
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
            Jellyseerr = {
              icon = "jellyseerr.svg";
              href = "https://request-media.hugo-berendi.de";
              description = "Media requests";
              widget = {
                type = "jellyseerr";
                url = "https://request-media.hugo-berendi.de";
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
            Redlib = {
              icon = "redlib.svg";
              href = "https://redlib.hugo-berendi.de";
              description = "Reddit client";
            };
          }
          {
            Commafeed = {
              icon = "mdi-rss";
              href = "https://rss.hugo-berendi.de";
              description = "RSS reader";
            };
          }
          {
            Pelican = {
              icon = "mdi-feather";
              href = "https://pelican.hugo-berendi.de";
              description = "Game server panel";
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
