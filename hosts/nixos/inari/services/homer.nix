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
            (mkHomerService
              "Grafana"
              "Pretty dashboards :3"
              (getIconUrl "grafana")
              "https://grafana.hugo-berendi.de")
            (mkHomerService
              "Syncthing"
              "File synchronization"
              (getIconUrl "syncthing")
              "https://syncthing.lapetus.hugo-berendi.de")
            (mkHomerService
              "Tailscale"
              "Access this homelab from anywhere"
              (getIconUrl "tailscale")
              "https://tailscale.com/")
            (mkHomerService
              "Dotfiles"
              "Configuration for all my machines"
              (getIconUrl "github")
              "https://github.com/hugo-berendi/yomi")
            (mkHomerService
              "Cloudflare"
              "Domain management"
              (getIconUrl "cloudflare")
              "https://dash.cloudflare.com/761d3e81b3e42551e33c4b73274ecc82/hugo-berendi.de/")
            (mkHomerService
              "Authentik"
              "OAuth, OICD, SSO and more"
              (getIconUrl "authentik")
              "https://authentik.hugo-berendi.de")
          ];
        }
        # }}}
        # {{{ Tooling
        {
          name = "Tooling";
          icon = fa "toolbox";
          items = [
            (mkHomerService
              "Vaultwarden"
              "Password manager"
              (getIconUrl "bitwarden")
              "https://warden.hugo-berendi.de")
            (mkHomerService
              "Whoogle"
              "Search engine"
              (getIconUrl "whoogle")
              "https://search.hugo-berendi.de")
            (mkHomerService
              "Radicale"
              "Calendar server"
              (getIconUrl "radicale")
              "https://cal.hugo-berendi.de")
            (mkHomerService
              "Microbin"
              "Code & file sharing"
              (getIconUrl "microbin")
              "https://bin.hugo-berendi.de")
            (mkHomerService
              "Forgejo"
              "Git forge"
              (getIconUrl "forgejo")
              "https://git.hugo-berendi.de")
            (mkHomerService
              "Jupyterhub"
              "Notebook collaboration suite"
              (getIconUrl "jupyter")
              "https://jupyter.hugo-berendi.de")
          ];
        }
        # }}}
        # {{{ Entertainment
        {
          name = "Entertainment";
          icon = fa "gamepad";
          items = [
            (mkHomerService
              "Invidious"
              "Youtube client"
              (getIconUrl "invidious")
              "https://yt.hugo-berendi.de")
            (mkHomerService
              "Redlib"
              "Reddit client"
              (getIconUrl "redlib")
              "https://redlib.hugo-berendi.de")
            (mkHomerService
              "Commafeed"
              "RSS reader"
              (getIconUrl "commafeed")
              "https://rss.hugo-berendi.de")
            (mkHomerService
              "Qbittorrent"
              "Torrent client"
              (getIconUrl "qbittorrent")
              "https://qbit.hugo-berendi.de")
            (mkHomerService
              "Jellyfin"
              "Media server"
              (getIconUrl "jellyfin")
              "https://media.hugo-berendi.de")
            (mkHomerService
              "Navidrome"
              "Music server"
              (getIconUrl "navidrome")
              "https://navidrome.hugo-berendi.de")
            (mkHomerService
              "Suwayomi"
              "Comic server"
              (getIconUrl "suwayomi")
              "https://suwayomi.hugo-berendi.de")
          ];
        }
        # }}}
      ];
    };
  };
}
