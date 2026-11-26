{
  config,
  lib,
  outputs,
  pkgs,
  ...
}: let
  enabled = lib.filterAttrs (_: endpoint: endpoint.enable);
  routes = access: endpoints:
    lib.mapAttrsToList (name: endpoint: {
      inherit name access;
      inherit (endpoint) host url protocol port;
      check = lib.optionalAttrs endpoint.monitor.enable {
        inherit (endpoint.monitor) name group;
      };
    }) (enabled endpoints);
  gatewayConfig = outputs.nixosConfigurations.ebisu.config;
  gateway = gatewayConfig.yomi.expose.server;
  throughGateway = config.yomi.expose.enable && gateway.enable && lib.elem config.networking.hostName gateway.sourceHosts;
  services =
    lib.optionals config.yomi.nginx.enable (routes "nginx" config.yomi.nginx.at)
    ++ lib.optionals throughGateway (routes "Pangolin" config.yomi.expose.at);
  # {{{ Access graph
  # Nodes and edges come from the evaluated configurations of this host and
  # its gateway; the page only lays them out. A component that is switched off
  # disappears together with every edge that touches it.
  hostLabel = name: lib.toUpper (builtins.substring 0 1 name) + builtins.substring 1 (-1) name;
  gatewayName = gatewayConfig.networking.hostName;
  publicWeb = throughGateway && enabled config.yomi.expose.at != {};
  publicRaw = throughGateway && config.yomi.expose.listeners != [];
  # NetBird devices reach inari through ebisu's NetBird and get the LAN's ports.
  netbird = config.services.netbird.enable && throughGateway && gatewayConfig.systemd.services ? netbird-server;
  lanWeb = config.yomi.nginx.enable && enabled config.yomi.nginx.at != {};
  listenerText = lib.concatMapStringsSep ", " (e: "${lib.toUpper e.protocol} ${toString e.port}") config.yomi.expose.listeners;
  rawNames = lib.concatStringsSep ", " (lib.attrNames (enabled config.yomi.expose.tcp // enabled config.yomi.expose.udp));
  gatewayServices = gatewayConfig.services;
  graphNodes =
    lib.optional (publicWeb || publicRaw) {
      id = "internet";
      label = "Internet";
      zone = "access";
    }
    ++ lib.optional netbird {
      id = "client";
      label = "VPN-Client";
      zone = "access";
      detail = "NetBird";
    }
    ++ lib.optional lanWeb {
      id = "lan";
      label = "Heimnetz";
      zone = "access";
    }
    ++ lib.optionals throughGateway (
      lib.optional gatewayServices.traefik.enable {
        id = "traefik";
        label = "Traefik";
        zone = gatewayName;
        detail = "TLS · Routing";
      }
      ++ lib.optional gatewayServices.pangolin.enable {
        id = "pangolin";
        label = "Pangolin";
        zone = gatewayName;
        detail = "Auth · Steuerung";
      }
      ++ lib.optional (gatewayConfig.systemd.services ? gerbil) {
        id = "gerbil";
        label = "Gerbil";
        zone = gatewayName;
        detail = "WireGuard-Endpunkt";
      }
      ++ lib.optional netbird {
        id = "netbird";
        label = "NetBird";
        zone = gatewayName;
        detail = "Anmeldung · Relay";
      }
    )
    ++ lib.optional config.services.newt.enable {
      id = "newt";
      label = "Newt";
      zone = config.networking.hostName;
      detail = "Site-Connector";
    }
    ++ lib.optional lanWeb {
      id = "nginx";
      label = "nginx";
      zone = config.networking.hostName;
      detail = "TLS · Reverse Proxy";
    }
    ++ lib.optional (publicWeb || lanWeb) {
      id = "web";
      label = "Webdienste";
      zone = config.networking.hostName;
      detail = "${toString (builtins.length (lib.unique (map (s: s.host) services)))} Hostnamen";
      href = "#services-title";
    }
    ++ lib.optional publicRaw {
      id = "raw";
      label = "Rohports";
      zone = config.networking.hostName;
      detail = rawNames;
    }
    ++ lib.optional netbird {
      id = "netbird-peer";
      label = "NetBird";
      zone = config.networking.hostName;
      detail = "Routing-Peer · Exit Node";
    };
  graphEdges =
    [
      {
        from = "internet";
        to = "traefik";
        label = lib.concatStringsSep " · " (lib.optional publicWeb "HTTPS 443" ++ lib.optional publicRaw listenerText);
      }
      {
        from = "traefik";
        to = "pangolin";
        label = "Auth";
        kind = "control";
      }
      {
        from = "traefik";
        to = "gerbil";
        label = "Proxy";
      }
      {
        from = "gerbil";
        to = "newt";
        label = "WireGuard";
        kind = "tunnel";
      }
      {
        from = "newt";
        to = "pangolin";
        label = "WebSocket";
        kind = "control";
      }
      {
        from = "client";
        to = "netbird";
        label = "Anmeldung · Relay TCP 443";
        kind = "control";
      }
      {
        from = "client";
        to = "netbird-peer";
        label = "WireGuard direkt";
        kind = "tunnel";
      }
      {
        from = "netbird";
        to = "netbird-peer";
        label = "Relay";
        kind = "tunnel";
      }
      {
        from = "netbird-peer";
        to = "nginx";
        label = "HTTPS 443";
      }
      {
        from = "lan";
        to = "nginx";
        label = "HTTPS 443";
      }
      {
        from = "nginx";
        to = "web";
        label = "HTTP(S)";
      }
    ]
    ++ lib.optional publicWeb {
      from = "newt";
      to = "web";
      label = "HTTP(S)";
    }
    ++ [
      {
        from = "newt";
        to = "raw";
        label = "TCP/UDP";
      }
    ];
  nodeIds = map (node: node.id) graphNodes;
  graph = {
    zones =
      [
        {
          id = "access";
          label = "Zugang";
          frame = false;
        }
      ]
      ++ lib.optional throughGateway {
        id = gatewayName;
        label = hostLabel gatewayName;
        detail = "VPS · ${gatewayConfig.yomi.expose.publicHost}";
      }
      ++ [
        {
          id = config.networking.hostName;
          label = hostLabel config.networking.hostName;
          detail = "Heimserver";
        }
      ];
    nodes = graphNodes;
    edges = lib.filter (edge: lib.elem edge.from nodeIds && lib.elem edge.to nodeIds) graphEdges;
  };
  # }}}
  data = pkgs.writeText "yomi-topology.json" (builtins.toJSON {
    host = config.networking.hostName;
    hosts = builtins.attrNames outputs.nixosConfigurations;
    inherit graph services;
    flows =
      [
        {
          from = "Grafana";
          to = "Prometheus";
          label = "Metriken · HTTP";
          scope = "Inari";
        }
        {
          from = "Grafana";
          to = "Loki";
          label = "Logabfragen · HTTP";
          scope = "Inari";
        }
        {
          from = "Alloy";
          to = "Loki";
          label = "Systemjournal · HTTP";
          scope = "Inari";
        }
      ]
      ++ lib.optionals (config.services.n8n.enable && builtins.hasAttr "actual-bridge" config.systemd.services) [
        {
          from = "n8n";
          to = "Actual Bridge";
          label = "Budget-Workflow · HTTP";
          scope = "Inari";
        }
        {
          from = "Actual Bridge";
          to = "Actual Budget";
          label = "Budget-API · HTTP";
          scope = "Inari";
        }
      ]
      ++ lib.optional (config.services.nextcloud.enable && config.services.nextcloud.database.createLocally) {
        from = "Nextcloud";
        to = "PostgreSQL";
        label = "Anwendungsdaten";
        scope = "Inari";
      }
      ++ lib.optionals config.yomi.restic.enable [
        {
          from = "Amaterasu";
          to = "Inari";
          label = "Restic · SFTP im Heimnetz";
          scope = "Backups";
        }
        {
          from = "Inari";
          to = "raid5pool";
          label = "Restic · lokales ZFS";
          scope = "Backups";
        }
      ]
      ++ lib.optional config.yomi.restic.offsite.enable {
        from = "Inari";
        to = "Backblaze B2";
        label = "Restic · HTTPS";
        scope = "Backups";
      }
      ++ lib.optional (gateway.enable && gateway.backup.enable) {
        from = "Ebisu";
        to = "Backblaze B2";
        label = "Pangolin-Backup · HTTPS";
        scope = "Backups";
      };
  });
  page = pkgs.writeText "yomi-topology.html" (builtins.readFile ./infrastructure-topology.html);
in {
  services.nginx.virtualHosts.${config.yomi.web.at.lab.host}.locations = {
    "= /infrastruktur".return = "308 /infrastruktur/";
    "= /infrastruktur/".extraConfig = "index /infrastruktur/index.html;";
    "= /infrastruktur/index.html" = {
      alias = page;
      extraConfig = "default_type text/html;";
    };
    "= /infrastruktur/topology.json" = {
      alias = data;
      extraConfig = ''
        default_type application/json;
        add_header Cache-Control "no-cache";
      '';
    };
    "= /infrastruktur/status.json".proxyPass = "http://127.0.0.1:${toString config.yomi.ports.gatus}/api/v1/endpoints/statuses";
  };
}
