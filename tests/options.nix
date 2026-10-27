{
  pkgs,
  configurations,
}: let
  inherit (pkgs) lib;
  base = configurations.inari;
  extend = module: (base.extendModules {modules = [module];}).config;
  check = name: condition: {
    inherit name;
    assertion = condition;
  };
  valid = c: lib.all (a: a.assertion) c.assertions;
  endpoint = extend {
    yomi.nginx.at.fixture = {
      host = "custom.example.org";
      dns = {
        name = "custom";
        zone = "example.org";
      };
      port = 19200;
    };
    yomi.nginx.at.disabled-fixture = {enable = false;};
    yomi.cloudflared.at.disabled-fixture = {enable = false;};
    yomi.cloudflared.at.protected-fixture = {
      port = 19201;
      enableIocaine = true;
      enableAnubis = true;
    };
  };
  disabled = extend ({lib, ...}: {yomi.nginx.enable = lib.mkForce false;});
  mismatch = extend {
    yomi.nginx.at.fixture = {
      host = "custom.example.org";
      port = 19200;
    };
  };
  duplicate = extend {
    yomi.nginx.at.fixture = {
      host = base.config.yomi.nginx.at.immich.host;
      dns.enable = false;
      port = 19200;
    };
  };
  collision = extend {yomi.ports.fixture = base.config.yomi.ports.forgejo + 200;};
  overflow = extend {
    yomi.cloudflared.at.fixture = {
      port = 65530;
      enableAnubis = true;
    };
  };
  backups = extend {
    yomi.restic.sets.fixture = {
      repository = "/tmp/fixture";
      paths = ["/var/lib/fixture"];
      requires = ["fixture-dump.service"];
    };
    yomi.restic.sets.disabled-fixture.enable = false;
    yomi.persistence.at.state.apps.fixture = {
      directories = [
        {
          directory = "/var/lib/fixture";
          user = "fixture";
          group = "fixture";
        }
      ];
      backupSets = ["fixture"];
    };
  };
  disabledOffsite = extend {yomi.restic.sets.offsite.enable = false;};
  badExposure = extend {
    yomi.network.exposure.fixture = {
      port = 19200;
      interface = "br0";
      scope = "wan";
    };
  };
  games = extend {
    services.windrose = {
      enable = true;
      passwordFile = "/run/secrets/fixture-password";
    };
    services.steamGameServers.fixture = {
      enable = true;
      appId = "123";
      script = "exit 0";
      openFirewall = false;
    };
    services.steamGameServers.disabled-fixture.enable = false;
  };
  apex =
    (lib.evalModules {
      specialArgs = {inherit pkgs;};
      modules = [
        ../dns/implementation/nixos-module.nix
        {
          yomi.dns = {
            domain = "example.org";
            records = [
              {
                at = null;
                type = "A";
                value = "192.0.2.1";
              }
            ];
          };
        }
      ];
    }).config.yomi.dns.records;
  dnsChecks = import ../dns/implementation/validate-records.nix {
    inherit lib;
    records = [
      {
        at = "www";
        zone = "example.org";
        type = "A";
        value = "192.0.2.1";
      }
      {
        at = "www";
        zone = "example.org";
        type = "CNAME";
        value = "elsewhere.example.org.";
      }
    ];
  };
  remote = extend ({lib, ...}: {
    yomi.remoteAccess = {
      enable = lib.mkForce true;
      upstream = "http://127.0.0.1:19704";
    };
    yomi.ports.remote-access = 19702;
    yomi.ports.oauth2-proxy = 19703;
  });
  remoteVhosts = lib.filterAttrs (name: _: lib.hasPrefix "remote-" name && name != "remote-default") remote.services.nginx.virtualHosts;
  checks =
    [
      (check "remote access vhosts all demand a login" (remoteVhosts != {} && lib.all (v: lib.hasPrefix "auth_request /oauth2/auth;" v.extraConfig) (lib.attrValues remoteVhosts) && valid remote))
      (check "remote access admits listed accounts only" (remote.services.oauth2-proxy.email.domains == [] && remote.services.oauth2-proxy.email.addresses != null))
      (check "host override and matching DNS" (endpoint.yomi.nginx.at.fixture.host == "custom.example.org" && valid endpoint))
      (check "disabled endpoints need no upstream and create no vhost" (!(endpoint.services.nginx.virtualHosts ? "disabled-fixture.hugo-berendi.de") && !(endpoint.services.cloudflared.tunnels.${endpoint.yomi.cloudflared.tunnel}.ingress ? "disabled-fixture.hugo-berendi.de")))
      (check "iocaine is in the tunnel request path" (endpoint.services.cloudflared.tunnels.${endpoint.yomi.cloudflared.tunnel}.ingress."protected-fixture.hugo-berendi.de".service == "http://127.0.0.1:19601"))
      (check "nginx forwards protected traffic through Anubis" (endpoint.services.nginx.virtualHosts.tunnel-protected-fixture.locations."/".proxyPass == "http://127.0.0.1:19401"))
      (check "nginx disable removes endpoint DNS" (!(lib.any (r: r.at == "immich") disabled.yomi.dns.records)))
      (check "hostname mismatch rejected" (!valid mismatch))
      (check "duplicate hostname rejected" (!valid duplicate))
      (check "derived port collision rejected" (!valid collision))
      (check "derived port overflow rejected" (!(builtins.tryEval (builtins.deepSeq overflow.yomi.ports true)).success))
      (check "DNS apex normalized" ((builtins.head apex).at == ""))
      (check "CNAME coexistence rejected" (!(lib.all (a: a.assertion) dnsChecks)))
      (check "custom backup prerequisites ordered" (lib.elem "fixture-dump.service" backups.systemd.services.restic-backups-fixture.after && lib.elem "fixture-dump.service" backups.systemd.services.restic-backups-fixture.requires))
      (check "disabled backup omitted" (!(backups.services.restic.backups ? disabled-fixture)))
      (check "disabled offsite does not leave an empty service" (!(disabledOffsite.systemd.services ? restic-backups-offsite)))
      (check "unsupported exposure rejected" (!valid badExposure))
      (check "persistence keeps ownership" ((builtins.head (lib.filter (d: d.directory == "/var/lib/fixture") backups.environment.persistence."/persist/state".directories)).user == "fixture"))
      (check "backup selection explicit" (lib.elem "/var/lib/fixture" backups.services.restic.backups.fixture.paths))
      (check "game server credentials stay runtime-only" (lib.elem "server-password:/run/secrets/fixture-password" games.systemd.services.windrose.serviceConfig.LoadCredential))
      (check "disabled game server omitted" (!(games.systemd.services ? steam-game-server-disabled-fixture)))
      (check "game server generates a command" (games.systemd.services.steam-game-server-fixture.serviceConfig ? ExecStart))
      (check "postgres dumps precede both backup destinations" (lib.all (name: lib.elem "postgresqlBackup.service" base.config.systemd.services.${name}.requires) ["restic-backups-state" "restic-backups-offsite"]))
      (check "offsite requires a fresh application state copy" (lib.elem "restic-app-state.service" base.config.systemd.services.restic-backups-offsite.requires && lib.elem "restic-app-state.service" base.config.systemd.services.restic-backups-offsite.after))
      (check "offsite includes the staged application state" (lib.elem base.config.systemd.services.restic-app-state.environment.APP_STATE_DESTINATION base.config.services.restic.backups.offsite.paths))
      (check "recovery snapshots have a format tag" (lib.elem "--tag app-state-v1" base.config.services.restic.backups.offsite.extraBackupArgs))
      (check "Matrix bridge databases persist despite static service users" (lib.all (name: lib.any (d: d.directory == "/var/lib/${name}" && d.user == name && d.group == name) base.config.environment.persistence."/persist/state".directories) ["mautrix-discord" "mautrix-signal" "mautrix-whatsapp"]))
      (check "immich retains filesystem sandbox" (base.config.systemd.services.immich-server.serviceConfig.ProtectSystem == "strict" && lib.elem base.config.services.immich.mediaLocation base.config.systemd.services.immich-server.serviceConfig.ReadWritePaths))
      (check "collector retains disk access" (base.config.systemd.services.scrutiny-collector.serviceConfig.PrivateDevices == false))
      (check "miniflux address families have one definition" (base.config.systemd.services.miniflux.serviceConfig.RestrictAddressFamilies == ["AF_INET" "AF_INET6" "AF_UNIX" "AF_NETLINK"]))
      (check "installer and WSL do not run unused proxies" (lib.all (name: let c = configurations.${name}.config; in !c.services.nginx.enable && !c.yomi.iocaine.enable) ["iso" "tsukuyomi" "wsl-work"]))
    ]
    # One check per unit so a failure names the unit, and a unit that does not
    # exist (renamed, or never defined) is reported as missing instead of as an
    # empty command. A single lib.all over the list failed CI with no unit name.
    ++ map (name: let
      unit = base.config.systemd.services.${name} or null;
    in
      check "systemd unit ${name} exists and has a command" (unit != null && (unit.serviceConfig.ExecStart or "") != ""))
    ["immich-server" "immich-machine-learning" "immich-public-proxy" "karakeep-init" "karakeep-web" "karakeep-workers" "llama-cpp" "llama-cpp-classifier" "proton-mail-sorter"];
  failures = map (c: c.name) (lib.filter (c: !c.assertion) checks);
  proxyConfig = pkgs.writeText "endpoint-fixture.conf" ''
    daemon off;
    pid nginx.pid;
    error_log stderr;
    events {}
    http {
      access_log off;
      client_body_temp_path client_temp;
      proxy_temp_path proxy_temp;
      fastcgi_temp_path fastcgi_temp;
      uwsgi_temp_path uwsgi_temp;
      scgi_temp_path scgi_temp;
      ${endpoint.services.nginx.commonHttpConfig}
      server {
        listen 127.0.0.1:19601;
        ${endpoint.services.nginx.virtualHosts.tunnel-protected-fixture.extraConfig}
        location / { proxy_pass ${endpoint.services.nginx.virtualHosts.tunnel-protected-fixture.locations."/".proxyPass}; }
        location /.well-known/@iocaine { proxy_pass ${endpoint.services.nginx.virtualHosts.tunnel-protected-fixture.locations."/.well-known/@iocaine".proxyPass}; }
      }
      server { listen 127.0.0.1:19401; location / { return 200 "anubis upstream"; } }
      server { listen 127.0.0.1:${toString endpoint.yomi.iocaine.port}; location / { return 200 "iocaine trap"; } }

      # Remote access: the generated server bodies, a stand-in oauth2-proxy
      # that accepts one cookie, and a stand-in internal vhost.
      map $http_upgrade $connection_upgrade { default upgrade; "" close; }
      server {
        listen 127.0.0.1:19702 default_server;
        ${remote.services.nginx.virtualHosts.remote-default.extraConfig}
      }
      server {
        listen 127.0.0.1:19702;
        server_name ${remote.services.nginx.virtualHosts.remote-grafana.serverName};
        ${remote.services.nginx.virtualHosts.remote-grafana.extraConfig}
      }
      server {
        listen 127.0.0.1:19703;
        location = /oauth2/auth {
          if ($http_cookie ~ "_oauth2_proxy=valid") { return 202; }
          return 401;
        }
        location /oauth2/ { return 200 "oauth2 $http_x_forwarded_host"; }
      }
      server {
        listen 127.0.0.1:19704;
        location = /redirect { return 302 https://grafana.hugo-berendi.de/login; }
        location / { return 200 "upstream $host $http_origin"; }
      }
    }
  '';
in
  assert lib.assertMsg (failures == []) ("Option regression checks failed: " + lib.concatStringsSep ", " failures);
    pkgs.runCommand "yomi-option-checks" {nativeBuildInputs = [pkgs.jq pkgs.nginx pkgs.curl];} ''
      # Exercise the generated renderer twice with characters that must remain
      # data, not shell or JSON syntax. No game process or Steam update is run.
      mkdir -p "$TMPDIR/credentials"
      export CREDENTIALS_DIRECTORY="$TMPDIR/credentials"
      printf '%s\n' 'test"password\with$characters' > "$CREDENTIALS_DIRECTORY/server-password"
      ${builtins.replaceStrings ["/persist/data/windrose/server"] ["$TMPDIR/server"] games.services.steamGameServers.windrose.preStart}
      cp "$TMPDIR/server/R5/ServerDescription.json" "$TMPDIR/first.json"
      ${builtins.replaceStrings ["/persist/data/windrose/server"] ["$TMPDIR/server"] games.services.steamGameServers.windrose.preStart}
      cmp "$TMPDIR/first.json" "$TMPDIR/server/R5/ServerDescription.json"
      test "$(stat -c %a "$TMPDIR/server/R5/ServerDescription.json")" = 600
      jq -e --rawfile password "$CREDENTIALS_DIRECTORY/server-password" '.ServerDescription_Persistent.Password == ($password | rtrimstr("\n")) and .ServerDescription_Persistent.IsPasswordProtected' "$TMPDIR/first.json" > /dev/null
      nginx -p "$TMPDIR" -c ${proxyConfig} &
      nginx_pid=$!
      trap 'kill "$nginx_pid"; wait "$nginx_pid" || true' EXIT
      curl --retry 20 --retry-connrefused --retry-delay 1 --fail -s http://127.0.0.1:19601/ > "$TMPDIR/response"
      test "$(cat "$TMPDIR/response")" = 'anubis upstream'
      test "$(curl --fail -s -A GPTBot http://127.0.0.1:19601/test)" = 'iocaine trap'
      test "$(curl --fail -s -A GPTBot http://127.0.0.1:19601/.well-known/@iocaine/test)" = 'iocaine trap'

      # Remote access: no session is sent to the login, never to the service.
      remote() { curl -s -H 'Host: grafana-remote.hugo-berendi.de' "$@"; }
      test "$(remote -o /dev/null -w '%{http_code} %{redirect_url}' http://127.0.0.1:19702/d/x)" = '307 https://grafana-remote.hugo-berendi.de/oauth2/start?rd=/d/x'
      test "$(remote http://127.0.0.1:19702/oauth2/start)" = 'oauth2 grafana-remote.hugo-berendi.de'
      test "$(remote -b '_oauth2_proxy=valid' http://127.0.0.1:19702/d/x)" = 'upstream grafana.hugo-berendi.de '
      test "$(remote -b '_oauth2_proxy=valid' -H 'Origin: https://grafana-remote.hugo-berendi.de' http://127.0.0.1:19702/)" = 'upstream grafana.hugo-berendi.de https://grafana.hugo-berendi.de'
      test "$(remote -b '_oauth2_proxy=valid' -o /dev/null -w '%{redirect_url}' http://127.0.0.1:19702/redirect)" = 'https://grafana-remote.hugo-berendi.de/login'
      # A name that is not a listed endpoint gets the connection closed.
      # (`! cmd` would not trip set -e, so test the status explicitly.)
      if curl -s -H 'Host: anything.hugo-berendi.de' -b '_oauth2_proxy=valid' http://127.0.0.1:19702/; then
        echo "unlisted host was answered" >&2
        exit 1
      fi
      echo ${lib.escapeShellArg ("Passed " + toString (builtins.length checks) + " option regression checks")} > $out
    ''
