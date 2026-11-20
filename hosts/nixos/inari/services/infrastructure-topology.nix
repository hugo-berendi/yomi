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
  gateway = outputs.nixosConfigurations.ebisu.config.yomi.expose.server;
  throughGateway = config.yomi.expose.enable && gateway.enable && lib.elem config.networking.hostName gateway.sourceHosts;
  data = pkgs.writeText "yomi-topology.json" (builtins.toJSON {
    host = config.networking.hostName;
    hosts = builtins.attrNames outputs.nixosConfigurations;
    inherit throughGateway;
    privateAccess = throughGateway && config.yomi.expose.private != {};
    services =
      lib.optionals config.yomi.nginx.enable (routes "nginx" config.yomi.nginx.at)
      ++ lib.optionals throughGateway (routes "Pangolin" config.yomi.expose.at);
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
  services.nginx.virtualHosts.${config.yomi.nginx.at.lab.host}.locations = {
    "= /infrastruktur".return = "308 /infrastruktur/";
    "= /infrastruktur/" = {
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
