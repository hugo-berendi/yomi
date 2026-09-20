{
  config,
  lib,
  ...
}: let
  port = config.yomi.ports.gatus;
  mkHttp = name: {
    inherit name;
    group = "Services";
    url = "https://${name}.hugo-berendi.de";
    interval = "1m";
    conditions = ["[STATUS] == 200" "[RESPONSE_TIME] < 2000"];
    alerts = [
      {
        type = "email";
        failure-threshold = 3;
        success-threshold = 2;
        send-on-resolved = true;
        description = "${name} is down";
      }
    ];
  };
  mkHttpAt = url: name: {
    inherit name;
    group = "Services";
    inherit url;
    interval = "1m";
    conditions = ["[STATUS] == 200" "[RESPONSE_TIME] < 2000"];
    alerts = [
      {
        type = "email";
        failure-threshold = 3;
        success-threshold = 2;
        send-on-resolved = true;
        description = "${name} is down";
      }
    ];
  };
  mkInternalHttp = name: realPort: path: {
    inherit name;
    group = "Infrastructure";
    url = "http://127.0.0.1:${toString realPort}${path}";
    interval = "30s";
    conditions = ["[STATUS] == 200"];
    alerts = [
      {
        type = "email";
        failure-threshold = 3;
        success-threshold = 2;
        send-on-resolved = true;
        description = "${name} is down";
      }
    ];
  };
in {
  # {{{ Reverse proxy
  yomi.nginx.at.status.port = port;
  # }}}
  # {{{ Secrets
  sops.secrets.gatus_env = {
    sopsFile = ../secrets.yaml;
    owner = "gatus";
    group = "gatus";
  };
  # }}}
  # {{{ User/Group - upstream uses DynamicUser; we want a stable UID for persistence + sops chown
  users.groups.gatus = {};
  users.users.gatus = {
    isSystemUser = true;
    group = "gatus";
    home = "/var/lib/gatus";
  };
  # {{{ Service
  services.gatus = {
    enable = true;
    environmentFile = config.sops.secrets.gatus_env.path;
    settings = {
      web.port = port;

      storage = {
        type = "sqlite";
        path = "/var/lib/gatus/data.db";
      };

      ui = {
        title = "Yomi Status";
        headerStyle = "clean";
      };

      # {{{ Email alerting via no-reply migadu SMTP
      alerting.email = {
        from = "no-reply@tengu.hugo-berendi.de";
        username = "no-reply@tengu.hugo-berendi.de";
        host = "smtp.migadu.com";
        port = 465;
        to = "status@hugo-berendi.de";
        client-type = "ssl";
        password = "\${GATUS_SMTP_PASSWORD}";
        default-alert = {
          enabled = true;
          failure-threshold = 3;
          success-threshold = 2;
          send-on-resolved = true;
        };
      };
      # }}}

      endpoints = [
        # {{{ External-facing services (subdomain name == attr name)
        (mkHttpAt "https://auth.hugo-berendi.de" "pocket-id")
        (mkHttpAt "https://immich-share.hugo-berendi.de" "immich-share")
        (mkHttpAt "https://cloud.hugo-berendi.de" "owncloud")
        (mkHttpAt "https://media.hugo-berendi.de" "jellyfin")
        (mkHttpAt "https://request-media.hugo-berendi.de" "jellyseerr")
        (mkHttpAt "https://search.hugo-berendi.de" "searxng")
        (mkHttpAt "https://bin.hugo-berendi.de" "microbin")
        # }}}
        # {{{ Internal nginx vhosts (also reachable via tailscale)
        (mkHttp "git")
        (mkHttp "paperless")
        (mkHttp "immich")
        (mkHttp "lab")
        (mkHttp "n8n")
        (mkHttp "karakeep")
        (mkHttp "warden")
        (mkHttp "yt")
        (mkHttp "radarr")
        (mkHttp "sonarr")
        (mkHttp "lidarr")
        (mkHttp "readarr")
        (mkHttp "bazarr")
        (mkHttp "prowlarr")
        (mkHttp "torrent")
        (mkHttp "cal")
        (mkHttp "pdf")
        (mkHttp "grafana")
        (mkHttp "prometheus")
        (mkHttp "home")
        # guacamole has autoStart = false (deliberately, see 6f0401c) - it's
        # started on demand, so it's always "down" here. Not monitored.
        (mkHttp "adguard")
        (mkHttp "monitoring")
        # }}}
        # {{{ Local-only services (probe via 127.0.0.1 for tight SLA)
        (mkInternalHttp "loki" config.yomi.ports.loki "/ready")
        (mkInternalHttp "forgejo" config.yomi.ports.forgejo "")
        (mkInternalHttp "beszel" config.yomi.ports.beszel "")
        (mkInternalHttp "pocket-id" config.yomi.ports.pocket-id "")
        # }}}
      ];
    };
  };
  # }}}
  # {{{ Storage
  environment.persistence."/persist/state".directories = [
    {
      directory = "/var/lib/gatus";
      mode = "u=rwx,g=,o=";
      user = "gatus";
      group = "gatus";
    }
  ];

  systemd.services.gatus.serviceConfig = lib.mkMerge [
    {
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateDevices = true;
      PrivateMounts = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      RestrictNamespaces = true;
      RestrictSUIDSGID = true;
      SystemCallArchitectures = "native";
    }
    {
      PrivateNetwork = lib.mkForce false;
      RestrictAddressFamilies = lib.mkForce ["AF_INET" "AF_INET6" "AF_UNIX" "AF_NETLINK"];
    }
    {
      DynamicUser = lib.mkForce false;
      User = "gatus";
      Group = "gatus";
      AmbientCapabilities = ["CAP_NET_RAW"];
      CapabilityBoundingSet = ["CAP_NET_RAW"];
      ReadWritePaths = ["/var/lib/gatus"];
    }
  ];
  # }}}
}
