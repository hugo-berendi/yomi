{lib, ...}: let
  knownServices = [
    "actual"
    "adguard"
    "adguard-dns"
    "anonaddy"
    "bazarr"
    "commafeed"
    "flaresolverr"
    "forgejo"
    "forgejo-ssh"
    "glance"
    "grafana"
    "guacamole"
    "home-assistant"
    "homepage"
    "immich"
    "intray-api"
    "intray-client"
    "invidious"
    "iocaine"
    "ipp"
    "jellyfin"
    "jellyseerr"
    "jupyter-ai"
    "jupyterhub"
    "karakeep"
    "karakeep-browser"
    "keycloak"
    "komga"
    "lidarr"
    "loki"
    "matrix-tuwunel"
    "matrix-tuwunel-proxy"
    "meilisearch"
    "microbin"
    "minecraft"
    "mqtt"
    "n8n"
    "navidrome"
    "ntfy"
    "ollama"
    "open-webui"
    "owncloud"
    "paperless"
    "paperless-ai"
    "paperless-ai-rag"
    "pelican-node1"
    "pelican-panel"
    "pocket-id"
    "prometheus"
    "prometheus-exportarr-bazarr"
    "prometheus-exportarr-lidarr"
    "prometheus-exportarr-prowlarr"
    "prometheus-exportarr-radarr"
    "prometheus-exportarr-readarr"
    "prometheus-exportarr-sonarr"
    "prometheus-nginx-exporter"
    "prometheus-node-exporter"
    "prometheus-postgres-exporter"
    "prometheus-smartctl-exporter"
    "prometheus-systemd-exporter"
    "prometheus-zfs-exporter"
    "promtail"
    "prowlarr"
    "qbittorrent"
    "radarr"
    "radicale"
    "readarr"
    "redlib"
    "sabnzbd"
    "searxng"
    "smos-api"
    "smos-client"
    "smos-docs"
    "sonarr"
    "stirling-pdf"
    "suwayomi"
    "syncthing"
    "transmission_peer"
    "transmission_ui"
    "uptime-kuma"
    "vaultwarden"
    "whoogle"
  ];

  basePort = 8400;

  portAssignments = lib.listToAttrs (
    lib.imap0 (i: name: {
      inherit name;
      value = basePort + i;
    })
    knownServices
  );

  mkPortOption = name: defaultPort:
    lib.mkOption {
      type = lib.types.port;
      default = defaultPort;
      description = "Port for ${name}";
    };

  portOptions = lib.mapAttrs mkPortOption portAssignments;
in {
  options.yomi.ports = portOptions;

  config.assertions = [
    {
      assertion = true;
      message = ''
        To add a new service port, add the service name to the knownServices list
        in modules/nixos/ports.nix. Ports are auto-assigned alphabetically from ${toString basePort}.
      '';
    }
  ];
}
