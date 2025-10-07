{
  pkgs,
  config,
  lib,
  ...
}: let
  port = config.yomi.ports.homepage or 8082;
in {
	yomi.nginx.at.lab.port = port;

	services.homepage-dashboard = {
		enable = true;
		listenPort = port;

		settings = {
			title = "✨ The celestial citadel ✨";
			theme = "dark";
			color = "slate";
			headerStyle = "clean";
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

		services = [
			{
				Infrastructure = [
					{
						Prometheus = {
							icon = "prometheus.svg";
							href = "https://prometheus.hugo-berendi.de";
							description = "Monitoring system";
						};
					}
					{
						Grafana = {
							icon = "grafana.svg";
							href = "https://grafana.hugo-berendi.de";
							description = "Pretty dashboards :3";
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
						};
					}
					{
						"Uptime Kuma" = {
							icon = "uptime-kuma.svg";
							href = "https://uptime.hugo-berendi.de";
							description = "Service status monitoring";
						};
					}
					{
						"Adguard Home" = {
							icon = "adguard-home.svg";
							href = "https://adguard.hugo-berendi.de";
							description = "DNS filtering";
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
						};
					}
					{
						Karakeep = {
							icon = "mdi-karate";
							href = "https://karakeep.hugo-berendi.de";
							description = "Karate training tracker";
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
						};
					}
					{
						Navidrome = {
							icon = "navidrome.svg";
							href = "https://navidrome.hugo-berendi.de";
							description = "Music server";
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
						};
					}
					{
						Transmission = {
							icon = "transmission.svg";
							href = "https://torrent.hugo-berendi.de";
							description = "Torrent client";
						};
					}
					{
						Radarr = {
							icon = "radarr.svg";
							href = "https://radarr.hugo-berendi.de";
							description = "Movie management";
						};
					}
					{
						Sonarr = {
							icon = "sonarr.svg";
							href = "https://sonarr.hugo-berendi.de";
							description = "TV show management";
						};
					}
					{
						Lidarr = {
							icon = "lidarr.svg";
							href = "https://lidarr.hugo-berendi.de";
							description = "Music management";
						};
					}
					{
						Readarr = {
							icon = "readarr.svg";
							href = "https://readarr.hugo-berendi.de";
							description = "Book management";
						};
					}
					{
						Bazarr = {
							icon = "bazarr.svg";
							href = "https://bazarr.hugo-berendi.de";
							description = "Subtitle management";
						};
					}
					{
						Prowlarr = {
							icon = "prowlarr.svg";
							href = "https://prowlarr.hugo-berendi.de";
							description = "Indexer manager";
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
	};

	environment.persistence."/persist/state".directories = [
		"/var/lib/homepage-dashboard"
	];
}
