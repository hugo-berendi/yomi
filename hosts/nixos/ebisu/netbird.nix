# NetBird: private access to the home network. Pangolin keeps the public
# sites; NetBird carries everything else, because its clients fall back to a
# relay over WebSocket on TCP 443 when a network blocks UDP. Pangolin's tunnel
# is UDP only, and a school guest network that let HTTPS out but no UDP (not
# even QUIC on 443) left it with no way through.
#
# One process serves management, signal, relay and STUN (pkgs/netbird-server.nix)
# behind ebisu's Traefik, which already terminates TLS for Pangolin. Routes,
# groups, policies and the Pocket ID login live in NetBird's database and are
# set in the dashboard; inari joins as the routing peer.
{
  config,
  lib,
  pkgs,
  ...
}: let
  domain = "netbird.${config.yomi.dns.domain}";
  url = "https://${domain}";
  server = pkgs.callPackage ../../../pkgs/netbird-server.nix {};
  dashboard = config.services.netbird.server.dashboard.finalDrv;

  # {{{ Ports
  # Loopback only, behind Traefik, except STUN. Not in yomi.ports, which the
  # home fleet reads; ebisu's public ports are 80, 443, 3478/udp, 21820/udp,
  # 51820/udp and the raw resources.
  port = 8530;
  dashboardPort = 8531;
  metricsPort = 8532;
  healthPort = 8533;
  stunPort = 3478;
  # }}}

  # {{{ Secrets
  # Generated on ebisu at first start and never in Git; the start script
  # writes them into a runtime copy of the config. Losing store-key makes the
  # database unreadable, so the backup below carries the directory.
  stateDir = "/var/lib/private/netbird";
  snapshotDir = "/var/lib/netbird-snapshot";
  secrets = {
    "@RELAY_AUTH@" = "relay-auth";
    "@STORE_KEY@" = "store-key";
    "@COOKIE_KEY@" = "cookie-key";
    "@OWNER_HASH@" = "owner-hash";
  };
  # }}}

  settings = {
    server = {
      listenAddress = "127.0.0.1:${toString port}";
      exposedAddress = "${url}:443";
      stunPorts = [stunPort];
      inherit metricsPort;
      healthcheckAddress = "127.0.0.1:${toString healthPort}";
      logLevel = "info";
      logFile = "console";
      authSecret = "@RELAY_AUTH@";
      dataDir = "/var/lib/netbird";
      disableAnonymousMetrics = true;
      auth = {
        issuer = "${url}/oauth2";
        signKeyRefreshEnabled = true;
        sessionCookieEncryptionKey = "@COOKIE_KEY@";
        dashboardRedirectURIs = ["${url}/nb-auth" "${url}/nb-silent-auth"];
        cliRedirectURIs = ["http://localhost:53000/"];
        # A local admin exists from the first start. Without one, the
        # dashboard's /setup page lets whoever opens it first claim the
        # instance, and a new certificate is probed within minutes of
        # appearing in the CT logs. Its password is in secrets/owner-password;
        # this address is not a mailbox and stays apart from the Pocket ID
        # login.
        owner = {
          email = "admin@${domain}";
          password = "@OWNER_HASH@";
        };
      };
      # Every connection comes from Traefik on loopback. Unset, trustedPeers
      # defaults to 0.0.0.0/0 and the gRPC server believes a client's own
      # X-Forwarded-For.
      reverseProxy = {
        trustedHTTPProxies = ["127.0.0.1/32"];
        trustedPeers = ["127.0.0.1/32"];
      };
      store = {
        engine = "sqlite";
        encryptionKey = "@STORE_KEY@";
      };
    };
  };
  configTemplate = (pkgs.formats.yaml {}).generate "netbird-server.yaml" settings;

  prepare = pkgs.writeShellScript "netbird-server-prepare" ''
    set -eu
    umask 077
    PATH=${lib.makeBinPath [pkgs.coreutils pkgs.openssl pkgs.mkpasswd pkgs.replace-secret]}
    dir="$STATE_DIRECTORY/secrets"
    mkdir -p "$dir"
    new() { [ -s "$dir/$1" ] || printf %s "$2" > "$dir/$1"; }
    new relay-auth "$(openssl rand -base64 32 | tr -d '=')"
    new store-key "$(openssl rand -base64 32)"
    new cookie-key "$(openssl rand -hex 16)"
    if [ ! -s "$dir/owner-password" ]; then
      new owner-password "$(openssl rand -base64 24)"
      rm -f "$dir/owner-hash"
    fi
    new owner-hash "$(mkpasswd --method=bcrypt --rounds=12 --stdin < "$dir/owner-password")"

    config="$RUNTIME_DIRECTORY/config.yaml"
    install -m 0600 ${configTemplate} "$config"
    ${lib.concatStrings (lib.mapAttrsToList (placeholder: file: ''
        replace-secret ${placeholder} "$dir/${file}" "$config"
      '')
      secrets)}
  '';

  # sqlite3's backup API, not a file copy of live databases.
  snapshot = pkgs.writeShellScript "netbird-snapshot" ''
    set -eu
    umask 077
    PATH=${lib.makeBinPath [pkgs.coreutils pkgs.sqlite]}
    partial="${snapshotDir}.partial"
    rm -rf "$partial"
    mkdir -p "$partial"
    cp -a ${stateDir}/secrets "$partial/"
    for db in ${stateDir}/*.db; do
      [ -e "$db" ] || continue
      sqlite3 -readonly "$db" ".backup '$partial/$(basename "$db")'"
    done
    rm -rf ${snapshotDir}
    mv "$partial" ${snapshotDir}
  '';
in {
  # NetBird rides on the gateway's Traefik, so it runs only with the gateway.
  config = lib.mkIf config.yomi.expose.server.enable {
    # {{{ Server
    systemd.services.netbird-server = {
      description = "NetBird management, signal, relay and STUN";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target"];
      serviceConfig = {
        ExecStartPre = prepare;
        ExecStart = "${lib.getExe server} --config %t/netbird-server/config.yaml";
        Restart = "on-failure";
        DynamicUser = true;
        StateDirectory = "netbird";
        StateDirectoryMode = "0700";
        RuntimeDirectory = "netbird-server";
        RuntimeDirectoryMode = "0700";
        UMask = "0077";
        CapabilityBoundingSet = "";
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        ProtectSystem = "strict";
        RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX" "AF_NETLINK"];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = ["@system-service" "~@privileged"];
      };
    };
    networking.firewall.allowedUDPPorts = [stunPort];
    # }}}

    # {{{ Dashboard
    # A static build; the values are public and baked in at build time.
    services.netbird.server.dashboard = {
      enable = true;
      inherit domain;
      managementServer = url;
      settings = {
        AUTH_AUTHORITY = "${url}/oauth2";
        AUTH_AUDIENCE = "netbird-dashboard";
        AUTH_CLIENT_ID = "netbird-dashboard";
        AUTH_SUPPORTED_SCOPES = "openid profile email groups";
        AUTH_REDIRECT_URI = "/nb-auth";
        AUTH_SILENT_REDIRECT_URI = "/nb-silent-auth";
        # The dashboard image's default; the NixOS module's is idToken.
        NETBIRD_TOKEN_SOURCE = "accessToken";
      };
    };
    # Traefik proxies but serves no files, so a loopback nginx does, with the
    # dashboard image's own locations.
    services.nginx = {
      enable = true;
      virtualHosts.netbird-dashboard = {
        listen = [
          {
            addr = "127.0.0.1";
            port = dashboardPort;
          }
        ];
        root = dashboard;
        extraConfig = "error_page 404 /404.html;";
        locations = {
          "/" = {
            tryFiles = "$uri $uri.html $uri/ =404";
            extraConfig = ''add_header Cache-Control "no-store" always;'';
          };
          "= /netbird.wasm".extraConfig = "default_type application/wasm;";
          "= /ironrdp-pkg/ironrdp_web_bg.wasm".extraConfig = "default_type application/wasm;";
          "= /404.html".extraConfig = "internal;";
        };
      };
    };
    # }}}

    # {{{ Traefik
    # The paths NetBird's own Traefik setup routes. gRPC needs h2c to the
    # backend. websecure keeps Pangolin's 30-minute readTimeout rather than
    # NetBird's 0, which would let slow clients hold every public site's
    # connections; NetBird's long-lived streams reconnect on their own when it
    # cuts them.
    services.traefik.dynamicConfigOptions.http = let
      router = rule: service: priority: {
        entryPoints = ["websecure"];
        inherit rule service priority;
        tls.certResolver = "letsencrypt";
      };
      host = "Host(`${domain}`)";
    in {
      routers = {
        netbird-grpc = router "${host} && (PathPrefix(`/signalexchange.SignalExchange/`) || PathPrefix(`/management.ManagementService/`))" "netbird-grpc" 100;
        netbird-server = router "${host} && (PathPrefix(`/relay`) || PathPrefix(`/ws-proxy/`) || PathPrefix(`/api`) || PathPrefix(`/oauth2`))" "netbird-server" 100;
        netbird-dashboard = router host "netbird-dashboard" 1;
        netbird-redirect = {
          entryPoints = ["web"];
          rule = host;
          middlewares = ["netbird-https"];
          service = "netbird-dashboard";
        };
      };
      middlewares.netbird-https.redirectScheme = {
        scheme = "https";
        permanent = true;
      };
      services = {
        netbird-grpc.loadBalancer.servers = [{url = "h2c://127.0.0.1:${toString port}";}];
        netbird-server.loadBalancer.servers = [{url = "http://127.0.0.1:${toString port}";}];
        netbird-dashboard.loadBalancer.servers = [{url = "http://127.0.0.1:${toString dashboardPort}";}];
      };
    };
    # }}}

    # {{{ DNS
    yomi.dns.records = [
      {
        at = "netbird";
        type = "CNAME";
        value = "${config.yomi.expose.publicHost}.";
      }
    ];
    # }}}

    # {{{ Backup
    # Rides on the gateway's off-host restic set.
    systemd.services.netbird-snapshot = {
      description = "Consistent copy of NetBird's databases and keys for restic";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = snapshot;
      };
    };
    services.restic.backups = lib.mkIf config.yomi.expose.server.backup.enable {
      expose.paths = [snapshotDir];
    };
    systemd.services.restic-backups-expose = lib.mkIf config.yomi.expose.server.backup.enable {
      requires = ["netbird-snapshot.service"];
      after = ["netbird-snapshot.service"];
    };
    # }}}
  };
}
