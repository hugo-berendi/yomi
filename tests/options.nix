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
  };
  # A tunnel endpoint on the apex of a zone yomi does not otherwise use, so it
  # cannot collide with the real homepage endpoint.
  apexGateway = extend {
    yomi.expose.at.apex-fixture = {
      subdomain = "";
      host = "example.org";
      dns.zone = "example.org";
      port = 19202;
      sso = false;
    };
  };
  misplacedAlias = extend {
    yomi.dns.records = [
      {
        at = "www";
        type = "ALIAS";
        value = "target.example.org.";
      }
    ];
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
  collision = extend {yomi.ports.fixture = base.config.yomi.expose.at.git.anubis.port;};
  overflow = extend {
    yomi.expose.at.fixture = {
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
  checks =
    [
      (check "host override and matching DNS" (endpoint.yomi.nginx.at.fixture.host == "custom.example.org" && valid endpoint))
      (check "disabled nginx endpoints need no upstream and create no vhost" (!(endpoint.services.nginx.virtualHosts ? "disabled-fixture.hugo-berendi.de")))
      (check "nginx disable removes endpoint DNS" (!(lib.any (r: r.at == "immich") disabled.yomi.dns.records)))
      (check "hostname mismatch rejected" (!valid mismatch))
      (check "duplicate hostname rejected" (!valid duplicate))
      (check "derived port collision rejected" (!valid collision))
      (check "derived port overflow rejected" (!(builtins.tryEval (builtins.deepSeq overflow.yomi.ports true)).success))
      (check "DNS apex normalized" ((builtins.head apex).at == ""))
      (check "apex Pangolin endpoint publishes an unproxied ALIAS" (lib.any (r: r.zone == "example.org" && r.at == "" && r.type == "ALIAS" && r.value == "${apexGateway.yomi.expose.publicHost}." && !r.enableCloudflareProxy) apexGateway.yomi.dns.records && valid apexGateway))
      (check "ALIAS below the apex rejected" (!valid misplacedAlias))
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
      (check "installer and WSL do not run unused proxies" (lib.all (name: let c = configurations.${name}.config; in !c.services.nginx.enable && !c.yomi.iocaine.enable) ["iso" "tsukuyomi" "wsl-work"]))
    ]
    # One check per unit so a failure names the unit, and a unit that does not
    # exist (renamed, or never defined) is reported as missing instead of as an
    # empty command. A single lib.all over the list failed CI with no unit name.
    ++ map (name: let
      unit = base.config.systemd.services.${name} or null;
    in
      check "systemd unit ${name} exists and has a command" (unit != null && (unit.serviceConfig.ExecStart or "") != ""))
    ["immich-server" "immich-machine-learning" "immich-public-proxy" "karakeep-init" "karakeep-web" "karakeep-workers" "llama-cpp-classifier" "proton-mail-sorter"];
  failures = map (c: c.name) (lib.filter (c: !c.assertion) checks);
in
  assert lib.assertMsg (failures == []) ("Option regression checks failed: " + lib.concatStringsSep ", " failures);
    pkgs.runCommand "yomi-option-checks" {nativeBuildInputs = [pkgs.jq];} ''
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
      echo ${lib.escapeShellArg ("Passed " + toString (builtins.length checks) + " option regression checks")} > $out
    ''
