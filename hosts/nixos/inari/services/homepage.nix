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
              widget = {
                type = "suwayomi";
                url = "http://127.0.0.1:${toString config.yomi.ports.suwayomi}";
                fields = ["unread" "downloadedunread"];
              };
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
