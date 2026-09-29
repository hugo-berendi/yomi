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

  # Explicit Radicale collection -> Google calendar pairs, keyed by a pair
  # name of your choosing. Fill in from `vdirsyncer-google discover` output:
  # Radicale ids are the UUID path segments, Google ids look like e-mail
  # addresses and need not match the calendar's display name.
  #
  #   family = { radicale = "e1119057-..."; google = "abc123@group.calendar.google.com"; };
  #
  # While this is empty the pair falls back to ["from a" "from b"], which is
  # only for discovery: it selects every collection on both sides.
  calendars = {};

  # Keep false until a manual `systemctl start ${syncUnit}` has been checked on
  # both sides. Flipping it adds the timer and the path unit to their targets.
  automate = false;

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
