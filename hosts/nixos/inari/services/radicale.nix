{
  config,
  lib,
  pkgs,
  ...
}: let
  port = config.yomi.ports.radicale;
  dataDir = "/persist/data/radicale";

  # {{{ Google sync settings
  syncJob = "radicale_google";
  syncUnit = "vdirsyncer@${syncJob}";
  syncUser = "calendar-sync";
  syncState = "/var/lib/vdirsyncer";
  triggerFile = "/run/radicale-sync-trigger/changed";

  # The htpasswd entry that owns the calendars. Radicale's default rights are
  # owner_only, so vdirsyncer has to log in as the owner to see them at all.
  radicaleUser = "hugob";

  # Radicale collection -> Google calendar, one pair each, taken from
  # `vdirsyncer-google discover` output. Radicale ids are the UUID path
  # segments; Google ids need not match the display name. Google's CalDAV
  # cannot create calendars, so a new pair needs its Google calendar made in
  # the web UI first. An empty set falls back to ["from a" "from b"], which
  # is only for discovery: it selects every collection on both sides.
  calendars = let
    gcal = id: "${id}@group.calendar.google.com";
  in {
    concerts = {
      radicale = "5fba7131-0cbb-a0d9-51af-3b092966f772";
      google = gcal "96b14cb8a4b27ac08e873d2df1e27d2a8c3f3458e3988aa9b5cb6bc3a80e4446";
    };
    series_movies = {
      radicale = "d4add776-f116-2e4b-d4a9-6d8184543dca";
      google = gcal "8a1396bc79c1c64d72e03283c04efc47e573a89951ffd691d838cb79fe563352";
    };
    programming = {
      radicale = "b3747fdf-ce93-8536-9bf6-efb4c3307408";
      google = gcal "60fac0f9f8f5210da4f71c384674a1327ca0a3cb31e659170c31c96981044a0e";
    };
    general = {
      radicale = "dd967f56-e6d7-572f-06ab-60142b423e22";
      google = gcal "3aa78957a8485381df501568ec307aac0ba2f7b208805eb314fe31036f247f17";
    };
    documents = {
      radicale = "9c68d359-d39e-1fbe-a37d-d9a2c963b908";
      google = gcal "5f0917ef39fd703a4933f5b5dafb4b096e6367a000845dc3e423aa9fb4c96369";
    };
    school = {
      radicale = "e1119057-4139-2be5-fa4b-2b8ac529a3cb";
      google = gcal "c32c68851f3a8118c6b403905295ada321aff58c4f87417d8a1547c2dba4ab53";
    };
    work = {
      radicale = "c65f759a-d734-d092-01ca-9544a24f2425";
      google = gcal "49150cfa6c4c6d9abd09a1db1eca7e4b52c4c206853ef5513584466c5a832b55";
    };
    scouts = {
      radicale = "ae5c8a55-1fdf-727a-e19c-885d5b553e46";
      google = gcal "3a409c521ac5e41a06f9fcdadc16c4fa19eab3ae3266e62f5c12abf6b890708c";
    };
    diabetes = {
      radicale = "394c354b-10e0-d4f5-cac5-e0201df0ebb2";
      google = gcal "c6fb48664c133e2cd03366c99d9631ec9e92a9039ae81e7d50a3da179b5aadca";
    };
  };

  # Initial sync was checked before enabling the timer and path trigger.
  # Google's exception revision workaround is described in docs/calendar-sync.md.
  automate = true;

  secret = name: ["command" "${pkgs.coreutils}/bin/cat" config.sops.secrets.${name}.path];

  # Radicale runs this synchronously while holding its storage lock, so it
  # only records that something changed and leaves the sync to its own unit.
  # It has to be a script rather than an inline command: Radicale %-formats
  # the hook string, which would eat date's format. A failing hook is only
  # logged by Radicale, it never fails the client's write.
  #
  # PathChanged= fires on close after write, which is why this writes the
  # file instead of touching it.
  notifyCalendarChange = pkgs.writeShellScript "radicale-calendar-changed" ''
    ${pkgs.coreutils}/bin/date +%s%N > ${triggerFile}
  '';

  # Discovery and the one-time Google OAuth consent have to run interactively,
  # as the service account and against the exact config the unit uses. The
  # config's store path changes on every rebuild, so this looks it up.
  vdirsyncerGoogle = pkgs.writeShellScriptBin "vdirsyncer-google" ''
    cd /
    exec /run/wrappers/bin/sudo -u ${syncUser} \
      ${pkgs.coreutils}/bin/env VDIRSYNCER_CONFIG=${config.systemd.services.${syncUnit}.environment.VDIRSYNCER_CONFIG} \
      ${config.services.vdirsyncer.package}/bin/vdirsyncer "$@"
  '';

  # Google answers a burst of CalDAV writes with 403 Forbidden. The first
  # sync of all nine pairs at once (vdirsyncer runs every collection
  # concurrently, up to 16 requests per host) had 13 of 43 uploads refused;
  # the same items went through with 201 when one collection ran alone.
  # vdirsyncer 0.20 has no concurrency setting, so sync one pair at a time.
  # A failed pair does not stop the rest; its items are retried next run.
  syncSequentially = pkgs.writeShellScript "vdirsyncer-${syncJob}-sequential" ''
    failed=0
    for collection in ${lib.escapeShellArgs (lib.attrNames calendars)}; do
      ${config.services.vdirsyncer.package}/bin/vdirsyncer sync "${syncJob}/$collection" || failed=1
    done
    exit "$failed"
  '';
  # }}}
in {
  # {{{ Radicale
  services.radicale = {
    enable = true;

    settings = {
      auth = {
        type = "htpasswd";
        htpasswd_filename = config.sops.secrets.radicale_htpasswd.path;
        htpasswd_encryption = "autodetect";
      };
      server.hosts = ["localhost:${toString port}"];
      storage = {
        filesystem_folder = dataDir;
        hook = "${notifyCalendarChange}";
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d ${dataDir} 0700 radicale radicale"
    "d ${dirOf triggerFile} 0700 radicale radicale - -"
    "f ${triggerFile} 0600 radicale radicale - -"
  ];
  yomi.nginx.at.cal.port = port;

  # ProtectSystem=strict leaves /run read-only for Radicale. The trigger file
  # is owned by radicale, which PrivateUsers= still maps to itself.
  systemd.services.radicale.serviceConfig = lib.mkMerge [
    {
      PrivateMounts = true;
    }
    {ReadWritePaths = [dataDir (dirOf triggerFile)];}
  ];
  # }}}
  # {{{ Google Calendar sync
  assertions = [
    {
      assertion = automate -> calendars != {};
      message = "radicale.nix: map explicit calendar pairs before automating the Google sync.";
    }
  ];

  services.vdirsyncer = {
    enable = true;
    # Google rejects independently versioned recurrence exceptions. Strip their
    # SEQUENCE only in the outgoing Google copy; leave source events untouched.
    package = pkgs.vdirsyncer.overrideAttrs (old: {
      patches =
        (old.patches or [])
        ++ [
          (builtins.path {
            path = ./radicale/google-recurrence-sequence.patch;
            name = "vdirsyncer-google-recurrence-sequence.patch";
          })
        ];
    });
    jobs.${syncJob} = {
      user = syncUser;
      group = syncUser;
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = "5min";
      };
      config = {
        pairs.${syncJob} = {
          a = "radicale";
          b = "google";
          # Radicale is the source of truth. Without this, any event present
          # on both sides with no status entry stops its collection: the
          # first sync aborted mid-collection, left 19 uploads unrecorded,
          # and Google's copies differed only by the CREATED/STATUS/TRANSP
          # it adds to everything it stores.
          conflict_resolution = "a wins";
          collections =
            if calendars == {}
            then ["from a" "from b"]
            else lib.mapAttrsToList (name: c: [name c.radicale c.google]) calendars;
        };
        storages = {
          # Straight to the loopback listener: no reason to go out through
          # nginx and back for a service on the same host.
          radicale = {
            type = "caldav";
            url = "http://127.0.0.1:${toString port}/";
            username = radicaleUser;
            "password.fetch" = secret "vdirsyncer_radicale_password";
            # Google's CalDAV only takes events; tasks kept in Radicale
            # would otherwise fail every run.
            item_types = ["VEVENT"];
          };
          google = {
            type = "google_calendar";
            token_file = "${syncState}/${syncJob}/google_token.json";
            "client_id.fetch" = secret "vdirsyncer_google_client_id";
            "client_secret.fetch" = secret "vdirsyncer_google_client_secret";
            item_types = ["VEVENT"];
          };
        };
      };
    };
  };

  users.users.${syncUser} = {
    isSystemUser = true;
    group = syncUser;
  };
  users.groups.${syncUser} = {};

  sops.secrets = let
    syncSecret = {
      sopsFile = ../secrets.yaml;
      owner = syncUser;
    };
  in {
    radicale_htpasswd = {
      sopsFile = ../secrets.yaml;
      owner = config.systemd.services.radicale.serviceConfig.User;
      group = config.systemd.services.radicale.serviceConfig.Group;
    };
    vdirsyncer_radicale_password = syncSecret;
    vdirsyncer_google_client_id = syncSecret;
    vdirsyncer_google_client_secret = syncSecret;
  };

  # Status and the OAuth token. Losing the status makes the next run treat
  # every event as new on both sides.
  environment.persistence."/persist/state".directories = [
    {
      directory = syncState;
      mode = "0700";
      user = syncUser;
      group = syncUser;
    }
  ];

  environment.systemPackages = [vdirsyncerGoogle];

  systemd.services.${syncUnit} = {
    serviceConfig.ExecStart = lib.mkIf (calendars != {}) (lib.mkForce ["${syncSequentially}"]);
    wants = ["network-online.target"];
    after = ["network-online.target"];
  };

  # Radicale -> Google within seconds instead of waiting for the timer. This
  # is best effort: a change landing while a sync is already running asks for
  # a start of an active unit, which systemd folds into the running job
  # rather than queueing another. The five-minute timer is what catches
  # those, and it is the only path for changes made on Google's side.
  #
  # vdirsyncer writing Google's changes into Radicale fires the hook too; that
  # start joins the running job, so it cannot loop.
  systemd.paths.${syncUnit} = {
    wantedBy = lib.optional automate "paths.target";
    pathConfig = {
      PathChanged = triggerFile;
      Unit = "${syncUnit}.service";
    };
  };
  # The upstream module always wants its timer; hold it back until automate.
  systemd.timers.${syncUnit}.wantedBy = lib.mkIf (!automate) (lib.mkForce []);
  # }}}
}
