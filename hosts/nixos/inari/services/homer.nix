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
  getIconUrl = name: "https://cdn.jsdelivr.net/gh/selfhst/icons/png/${name}.png";

  mkHomerService = {
    name,
    subtitle,
    logo,
    url,
    type ? "",
  }: {
    name = name;
    type = type;
    subtitle = subtitle;
    logo = logo;
    url = url;
  };
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
            (mkHomerService {
              name = "Prometheus";
              subtitle = "Monitoring system";
              logo = getIconUrl "prometheus";
              url = "https://prometheus.hugo-berendi.de";
              type = "Prometheus";
            })
            (mkHomerService {
              name = "Grafana";
              subtitle = "Pretty dashboards :3";
              logo = getIconUrl "grafana";
              url = "https://grafana.hugo-berendi.de";
            })
            (mkHomerService {
              name = "Syncthing";
              subtitle = "File synchronization";
              logo = getIconUrl "syncthing";
              url = "https://syncthing.lapetus.hugo-berendi.de";
            })
            (mkHomerService {
              name = "Tailscale";
              subtitle = "Access this homelab from anywhere";
              logo = getIconUrl "tailscale";
              url = "https://tailscale.com/";
            })
            (mkHomerService {
              name = "Dotfiles";
              subtitle = "Configuration for all my machines";
              logo = getIconUrl "github";
              url = "https://github.com/hugo-berendi/yomi";
            })
            (mkHomerService {
              name = "Cloudflare";
              subtitle = "Domain management";
              logo = getIconUrl "cloudflare";
              url = "https://dash.cloudflare.com/761d3e81b3e42551e33c4b73274ecc82/hugo-berendi.de/";
            })
            (mkHomerService {
              name = "Authentik";
              subtitle = "OAuth, OICD, SSO and more";
              logo = getIconUrl "authentik";
              url = "https://authentik.hugo-berendi.de";
            })
          ];
        }
        # }}}
        # {{{ Tooling
        {
          name = "Tooling";
          icon = fa "toolbox";
          items = [
            (mkHomerService {
              name = "Vaultwarden";
              subtitle = "Password manager";
              logo = getIconUrl "bitwarden";
              url = "https://warden.hugo-berendi.de";
            })
            (mkHomerService {
              name = "Whoogle";
              subtitle = "Search engine";
              logo = getIconUrl "whoogle";
              url = "https://search.hugo-berendi.de";
            })
            (mkHomerService {
              name = "Radicale";
              subtitle = "Calendar server";
              logo = getIconUrl "radicale";
              url = "https://cal.hugo-berendi.de";
            })
            (mkHomerService {
              name = "Microbin";
              subtitle = "Code & file sharing";
              logo = getIconUrl "microbin";
              url = "https://bin.hugo-berendi.de";
            })
            (mkHomerService {
              name = "Forgejo";
              subtitle = "Git forge";
              logo = getIconUrl "forgejo";
              url = "https://git.hugo-berendi.de";
            })
            (mkHomerService {
              name = "Jupyterhub";
              subtitle = "Notebook collaboration suite";
              logo = getIconUrl "jupyter";
              url = "https://jupyter.hugo-berendi.de";
            })
          ];
        }
        # }}}
        # {{{ Entertainment
        {
          name = "Entertainment";
          icon = fa "gamepad";
          items = [
            (mkHomerService {
              name = "Invidious";
              subtitle = "Youtube client";
              logo = getIconUrl "invidious";
              url = "https://yt.hugo-berendi.de";
            })
            (mkHomerService {
              name = "Redlib";
              subtitle = "Reddit client";
              logo = getIconUrl "redlib";
              url = "https://redlib.hugo-berendi.de";
            })
            (mkHomerService {
              name = "Commafeed";
              subtitle = "RSS reader";
              logo = getIconUrl "commafeed";
              url = "https://rss.hugo-berendi.de";
            })
            (mkHomerService {
              name = "Qbittorrent";
              subtitle = "Torrent client";
              logo = getIconUrl "qbittorrent";
              url = "https://qbit.hugo-berendi.de";
            })
            (mkHomerService {
              name = "Jellyfin";
              subtitle = "Media server";
              logo = getIconUrl "jellyfin";
              url = "https://media.hugo-berendi.de";
            })
            (mkHomerService {
              name = "Navidrome";
              subtitle = "Music server";
              logo = getIconUrl "navidrome";
              url = "https://navidrome.hugo-berendi.de";
            })
            (mkHomerService {
              name = "Suwayomi";
              subtitle = "Comic server";
              logo = getIconUrl "suwayomi";
              url = "https://suwayomi.hugo-berendi.de";
            })
          ];
        }
        # }}}
      ];
    };
  };
}
