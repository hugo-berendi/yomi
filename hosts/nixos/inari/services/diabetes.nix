{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.yomi.diabetes;
  python = pkgs.python3.withPackages (p: [p.flask p.waitress p.pydexcom p.matplotlib]);
  source = builtins.path {
    path = ./diabetes;
    name = "yomi-diabetes";
  };
  credentials =
    ["home-assistant-token:${config.sops.secrets.n8n_home_assistant_api_token.path}"]
    ++ lib.optional (cfg.dexcomCredentialFile != null) "dexcom:${cfg.dexcomCredentialFile}";
  environment = {
    MPLCONFIGDIR = "/var/lib/diabetes/matplotlib";
    HOME_ASSISTANT_URL = "http://127.0.0.1:${toString config.yomi.ports.home-assistant}";
    # A synthetic JSON selection timed out at 180s on the 14B. The existing
    # 3B classifier returned the minimal selection in 10s on this host.
    AI_URL = "http://127.0.0.1:${toString config.yomi.ports.llama-cpp-classifier}/v1/chat/completions";
    PUBLIC_URL = config.yomi.nginx.at.diabetes.url;
  };
in {
  # {{{ Options
  options.yomi.diabetes = {
    enable = lib.mkEnableOption "private diabetes reports and reminders";
    dexcomCredentialFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Runtime JSON file with Dexcom Share username/password; provision with sops, never a Nix store path.";
    };
  };
  # }}}
  config = lib.mkIf cfg.enable {
    system.build.diabetes-tests = pkgs.runCommand "yomi-diabetes-tests" {} ''
      export MPLCONFIGDIR="$TMPDIR/matplotlib"
      export PYTHONDONTWRITEBYTECODE=1
      ${python}/bin/python -m unittest discover -s ${source} -v
      touch "$out"
    '';
    assertions = [
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
      proxy_read_timeout 240s;
    '';
    users.groups.diabetes = {};
    users.users.diabetes = {
      isSystemUser = true;
      group = "diabetes";
    };
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
        MemoryMax = "512M";
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
        TimeoutStartSec = 240;
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        MemoryMax = "512M";
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
    # }}}
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
    services.home-assistant.extraComponents = ["dexcom" "mobile_app"];
  };
}
