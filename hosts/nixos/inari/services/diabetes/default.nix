{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.yomi.diabetes;
  python = pkgs.python3.withPackages (p: [p.flask p.waitress p.pydexcom p.matplotlib p.playwright]);
  source = builtins.path {
    path = ./.;
    # default.nix lives beside the sources; keep it out so the store path (and
    # every unit embedding it) does not change when the module is edited.
    filter = path: _: baseNameOf path != "default.nix";
    name = "yomi-diabetes";
  };
  loginHelper = pkgs.writeShellApplication {
    name = "diabetes-glooko-login";
    text = ''
      umask 077
      export STATE_DIRECTORY=/var/lib/diabetes
      export HOME=/var/lib/diabetes
      export MPLCONFIGDIR=/var/lib/diabetes/matplotlib
      export GLOOKO_CHROMIUM=${pkgs.chromium}/bin/chromium
      # The operator's home can be inaccessible after sudo changes the user.
      cd "$STATE_DIRECTORY"
      exec ${python}/bin/python ${source}/app.py auth-glooko
    '';
  };
  credentials =
    ["home-assistant-token:${config.sops.secrets.n8n_home_assistant_api_token.path}"]
    ++ lib.optional cfg.weeklyEmailEnable "weekly-smtp-password:${config.sops.secrets.no_reply_smtp_password.path}"
    ++ lib.optional (cfg.weeklyEmailEnable && cfg.weeklyMailCredentialFile != null) "weekly-mail:${cfg.weeklyMailCredentialFile}"
    ++ lib.optional (cfg.dexcomCredentialFile != null) "dexcom:${cfg.dexcomCredentialFile}";
  environment = {
    GLOOKO_CHROMIUM = "${pkgs.chromium}/bin/chromium";
    HOME = "/var/lib/diabetes";
    WEEKLY_EMAIL_ENABLED = lib.boolToString cfg.weeklyEmailEnable;
    MPLCONFIGDIR = "/var/lib/diabetes/matplotlib";
    HOME_ASSISTANT_URL = "http://127.0.0.1:${toString config.yomi.ports.home-assistant}";
    # The running classifier serves Qwen3.5-9B through llama.cpp.
    AI_URL = "http://127.0.0.1:${toString config.yomi.ports.llama-cpp-classifier}/v1/chat/completions";
    PUBLIC_URL = config.yomi.nginx.at.diabetes.url;
  };
in {
  # {{{ Options
  options.yomi.diabetes = {
    enable = lib.mkEnableOption "private diabetes reports and reminders";
    weeklyEmailEnable = lib.mkEnableOption "weekly email submission through the private n8n endpoint";
    weeklyMailCredentialFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "/var/lib/diabetes/weekly-mail.json";
      description = "Runtime JSON with confirmed recipient and optional SMTP settings. Defaults reuse the existing Migadu no-reply account through LoadCredential. Use a runtime private file or sops secret path, never a store path.";
    };
    dexcomCredentialFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Runtime JSON file with Dexcom Share username/password; provision with sops, never a Nix store path.";
    };
  };
  # }}}
  config = lib.mkMerge [
    {
      system.build.diabetes-glooko-login = loginHelper;
      system.build.diabetes-tests = pkgs.runCommand "yomi-diabetes-tests" {} ''
        export MPLCONFIGDIR="$TMPDIR/matplotlib"
        export PYTHONDONTWRITEBYTECODE=1
        ${python}/bin/python -m unittest discover -s ${source} -v
        touch "$out"
      '';
      # Keep the retired site's state mounted and backed up. Turning off the
      # web service must not discard health history or reassign its owner.
      users.groups.diabetes = {};
      users.users.diabetes = {
        isSystemUser = true;
        group = "diabetes";
      };
      # Retiring the site must not remove any device integrations already
      # configured in Home Assistant.
      services.home-assistant.extraComponents = ["dexcom" "mobile_app"];
      # {{{ Persistence and backups
      yomi.persistence.at.state.apps.diabetes.directories = [
        {
          directory = "/var/lib/diabetes";
          user = "diabetes";
          group = "diabetes";
          mode = "0700";
        }
      ];
      # The existing local restic state set already covers this path. Keep an
      # off-site copy too: normalized health history cannot be reacquired forever.
      yomi.restic.offsite.paths = ["/persist/state/var/lib/diabetes"];
      # }}}
    }
    (lib.mkIf cfg.enable {
      environment.systemPackages = [loginHelper];
      assertions = [
        {
          assertion = !cfg.weeklyEmailEnable || cfg.weeklyMailCredentialFile != null;
          message = "Weekly diabetes email needs a runtime mail credential with a confirmed recipient.";
        }
        {
          assertion = cfg.weeklyMailCredentialFile == null || !(lib.hasPrefix "/nix/store/" cfg.weeklyMailCredentialFile);
          message = "Weekly mail credentials must be a runtime secret, not a Nix store file.";
        }
        {
          assertion = cfg.dexcomCredentialFile == null || !(lib.hasPrefix "/nix/store/" cfg.dexcomCredentialFile);
          message = "Dexcom credentials must be a runtime secret, not a Nix store file.";
        }
      ];
      # {{{ Private web service
      yomi.nginx.at.diabetes = {
        port = config.yomi.ports.diabetes;
        clientMaxBodySize = "20m";
      };
      # The existing nginx endpoint resolves to inari's tailnet address. App
      # authentication still protects health data from other tailnet clients.
      services.nginx.virtualHosts.${config.yomi.nginx.at.diabetes.host}.locations."/".extraConfig = ''
        proxy_read_timeout 910s;
      '';
      systemd.services.diabetes = {
        description = "Private diabetes journal";
        wantedBy = ["multi-user.target"];
        after = ["network-online.target" "sops-nix.service"];
        wants = ["network-online.target"];
        environment =
          environment
          // lib.optionalAttrs (cfg.dexcomCredentialFile != null) {
            DEXCOM_CREDENTIAL_FILE = "%d/dexcom";
          };
        serviceConfig = {
          User = "diabetes";
          Group = "diabetes";
          StateDirectory = "diabetes";
          StateDirectoryMode = "0700";
          UMask = "0077";
          LoadCredential = credentials;
          ExecStart = "${python}/bin/python ${source}/app.py serve --port ${toString config.yomi.ports.diabetes}";
          Restart = "on-failure";
          RestartSec = 5;
          NoNewPrivileges = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          RestrictSUIDSGID = true;
          RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
          MemoryMax = "2G";
        };
      };
      # Background work runs independently of n8n so reminders also survive an
      # n8n credential/import outage. The optional workflow calls the same job
      # under its process lock; both routes converge on the same notification IDs.
      systemd.services.diabetes-jobs = {
        description = "Update diabetes reports and due reminders";
        requires = ["diabetes.service"];
        after = ["diabetes.service"];
        environment =
          environment
          // lib.optionalAttrs (cfg.dexcomCredentialFile != null) {
            DEXCOM_CREDENTIAL_FILE = "%d/dexcom";
          };
        serviceConfig = {
          Type = "oneshot";
          User = "diabetes";
          Group = "diabetes";
          StateDirectory = "diabetes";
          StateDirectoryMode = "0700";
          UMask = "0077";
          LoadCredential = credentials;
          ExecStart = "${python}/bin/python ${source}/app.py tick";
          TimeoutStartSec = 900;
          NoNewPrivileges = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          MemoryMax = "2G";
        };
      };
      systemd.timers.diabetes-jobs = {
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = "*:0/5";
          Persistent = true;
          RandomizedDelaySec = 10;
        };
      };
      systemd.services.diabetes-glooko = {
        description = "Import Glooko exports automatically";
        after = ["network-online.target" "diabetes.service"];
        wants = ["network-online.target"];
        environment = {
          GLOOKO_CHROMIUM = "${pkgs.chromium}/bin/chromium";
          HOME = "/var/lib/diabetes";
        };
        serviceConfig = {
          Type = "oneshot";
          User = "diabetes";
          Group = "diabetes";
          StateDirectory = "diabetes";
          StateDirectoryMode = "0700";
          UMask = "0077";
          ExecStart = "${python}/bin/python ${source}/app.py sync-glooko";
          TimeoutStartSec = 300;
          MemoryMax = "1G";
          NoNewPrivileges = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          RestrictSUIDSGID = true;
          RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
        };
      };
      systemd.timers.diabetes-glooko = {
        wantedBy = ["timers.target"];
        timerConfig = {
          # The application runs daily, with a six-hour backoff on failure.
          # Frequent checks let a newly saved login start without a manual command.
          OnCalendar = "*:0/5";
          Persistent = true;
          RandomizedDelaySec = 5;
        };
      };
      # }}}
    })
  ];
}
