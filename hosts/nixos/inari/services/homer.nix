{
  pkgs,
  config,
  ...
}: let
  # {{{ Colors
  colors = with config.lib.stylix.colors.withHashtag; {
    highlight-primary = base09;
    highlight-secondary = base01;
    highlight-hover = base00;
    text-header = base05;
    text-title = base05;
    text-subtitle = base05;
    text = base05;
    link = base08;
    background = base00;
    card-background = base01;
  };
  # }}}

  fa = name: "fas fa-${name}";
  iconPath = ../../../../common/icons;
  icon = file: "assets/${iconPath}/${file}";
in {
  yomi.nginx.at.lab.files = pkgs.homer.withAssets {
    extraAssets = [iconPath];
    config = {
      title = "✨ The celestial citadel ✨";

      header = false;
      footer = false;
      connectivityCheck = true;

      colors.light = colors;
      colors.dark = colors;

      services = [
        # {{{ Infrastructure
        {
          name = "Infrastructure";
          icon = fa "code";
          items = [
            {
              name = "Prometheus";
              type = "Prometheus";
              subtitle = "Monitoring system";
              logo = icon "prometheus.png";
              url = "https://prometheus.hugo-berendi.de";
            }
            {
              name = "Grafana";
              subtitle = "Pretty dashboards :3";
              logo = icon "grafana.png";
              url = "https://grafana.hugo-berendi.de";
            }
            {
              name = "Syncthing";
              subtitle = "File synchronization";
              logo = icon "syncthing.png";
              url = "https://syncthing.lapetus.hugo-berendi.de";
            }
            {
              name = "Guacamole";
              subtitle = "Server remote access";
              logo = icon "guacamole.png";
              url = "https://guacamole.hugo-berendi.de";
            }
          ];
        }
        # }}}
        # {{{ External
        {
          name = "External";
          icon = fa "arrow-up-right-from-square";
          items = [
            {
              name = "Tailscale";
              subtitle = "Access this homelab from anywhere";
              logo = icon "tailscale.png";
              url = "https://tailscale.com/";
            }
            {
              name = "Dotfiles";
              subtitle = "Configuration for all my machines";
              logo = icon "github.png";
              url = "https://github.com/prescientmoon/everything-nix";
            }
            {
              name = "Cloudflare";
              subtitle = "Domain management";
              logo = icon "cloudflare.png";
              url = "https://dash.cloudflare.com/761d3e81b3e42551e33c4b73274ecc82/hugo-berendi.de/";
            }
          ];
        }
        # }}}
        # {{{ Productivity
        {
          name = "Productivity";
          icon = fa "rocket";
          items = [
            {
              name = "Intray";
              subtitle = "GTD capture tool";
              icon = fa "inbox";
              url = "https://intray.hugo-berendi.de";
            }
            {
              name = "Smos";
              subtitle = "A comprehensive self-management system.";
              icon = fa "cubes-stacked";
              url = "https://smos.hugo-berendi.de";
            }
            {
              name = "Actual";
              subtitle = "Budgeting tool";
              logo = icon "actual.png";
              url = "https://actual.hugo-berendi.de";
            }
          ];
        }
        # }}}
        # {{{ Tooling
        {
          name = "Tooling";
          icon = fa "toolbox";
          items = [
            {
              name = "Vaultwarden";
              subtitle = "Password manager";
              logo = icon "bitwarden.png";
              url = "https://warden.hugo-berendi.de";
            }
            {
              name = "Whoogle";
              subtitle = "Search engine";
              logo = icon "whoogle.webp";
              url = "https://search.hugo-berendi.de";
            }
            {
              name = "Radicale";
              subtitle = "Calendar server";
              logo = icon "radicale.svg";
              url = "https://cal.hugo-berendi.de";
            }
            {
              name = "Microbin";
              subtitle = "Code & file sharing";
              logo = icon "microbin.png";
              url = "https://bin.hugo-berendi.de";
            }
            {
              name = "Forgejo";
              subtitle = "Git forge";
              logo = icon "forgejo.svg";
              url = "https://git.hugo-berendi.de";
            }
            {
              name = "Jupyterhub";
              subtitle = "Notebook collaboration suite";
              logo = icon "jupyter.png";
              url = "https://jupyter.hugo-berendi.de";
            }
          ];
        }
        # }}}
        # {{{ Entertainment
        {
          name = "Entertainment";
          icon = fa "gamepad";
          items = [
            {
              name = "Invidious";
              subtitle = "Youtube client";
              logo = icon "invidious.png";
              url = "https://yt.hugo-berendi.de";
            }
            {
              name = "Redlib";
              subtitle = "Reddit client";
              logo = icon "libreddit.png";
              url = "https://redlib.hugo-berendi.de";
            }
            {
              name = "Diptime";
              subtitle = "Diplomacy timer";
              icon = fa "globe";
              url = "https://diptime.hugo-berendi.de";
            }
            {
              name = "Commafeed";
              subtitle = "RSS reader";
              logo = icon "commafeed.png";
              url = "https://rss.hugo-berendi.de";
            }
            {
              name = "Qbittorrent";
              subtitle = "Torrent client";
              logo = icon "qbittorrent.png";
              url = "https://qbit.hugo-berendi.de";
            }
            {
              name = "Jellyfin";
              subtitle = "Media server";
              logo = icon "jellyfin.png";
              url = "https://media.hugo-berendi.de";
            }
          ];
        }
        # }}}
      ];
    };
  };
}
