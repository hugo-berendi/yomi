{
  config,
  lib,
  ...
}: let
  port = config.yomi.ports.gatus;
  endpoints =
    (
      if config.yomi.nginx.enable
      then lib.attrValues config.yomi.nginx.at
      else []
    )
    ++ lib.attrValues config.yomi.cloudflared.at;
  monitored = lib.filter (e: e.enable && e.monitor.enable) endpoints;
  mkEndpoint = e: {
    inherit (e.monitor) name group interval conditions;
    url = e.url + e.monitor.path;
    alerts = [
      {
        type = "email";
        failure-threshold = 3;
        success-threshold = 2;
        send-on-resolved = true;
        description = "${e.monitor.name} is down";
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
  yomi.cloudflared.at = lib.genAttrs ["pocket-id" "immich-share" "cloud" "media" "request-media" "search" "bin" "git"] (name: {
    monitor.enable = true;
    monitor.name =
      {
        cloud = "owncloud";
        media = "jellyfin";
        request-media = "jellyseerr";
        search = "searxng";
        bin = "microbin";
      }.${
        name
      } or name;
  });
  yomi.nginx.at = (lib.genAttrs ["paperless" "immich" "lab" "n8n" "karakeep" "warden" "yt" "radarr" "sonarr" "lidarr" "readarr" "bazarr" "prowlarr" "torrent" "cal" "pdf" "grafana" "prometheus" "home" "adguard" "monitoring"] (_: {monitor.enable = true;})) // {status.port = port;};
  # {{{ Reverse proxy
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

      endpoints =
        (map mkEndpoint monitored)
        ++ [
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
