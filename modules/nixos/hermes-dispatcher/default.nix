{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.yomi.hermesDispatcher;
  system = pkgs.stdenv.hostPlatform.system;
  app = import ./app.nix {
    inherit pkgs lib;
    hermesAgent = inputs.llm-agents.packages.${system}.hermes-agent;
    skillsSource = inputs.skills;
  };
  inherit (cfg.appPackage) hermes skills routes routingConfig;
  launcherSource = cfg.appPackage;
  codex = import ../../../home/features/cli/ai/codex-package.nix {
    inherit inputs pkgs;
    # ProtectKernelTunables masks proc subtrees. Keep that protection and let
    # Codex's existing proc fallback recognize external bubblewrap 0.12 too.
    codex = inputs.llm-agents.packages.${system}.codex.overrideAttrs (old: {
      patches = (old.patches or []) ++ [./codex-proc-fallback.patch];
      doCheck = true;
      cargoTestFlags = ["--package" "codex-linux-sandbox" "proc_mount_failure_tests"];
    });
  };
  state = cfg.stateDirectory;
  dispatch = import ./dispatch.nix {inherit config lib pkgs inputs state skills launcherSource routes;};
  settings = cfg.appPackage.mkSettings {inherit state;};
  # {{{ Alert webhook
  # Routes for the inari alert router (hosts/nixos/inari/services/n8n). The
  # launcher adds the signing secret and the verified private room at start.
  #
  # mirror_to_session stays off: Hermes would write the delivered text into
  # Hugo's chat session as a user turn, giving text derived from untrusted
  # logs Hugo's authority over Ciel's task tools.
  alertWebhook = {
    inherit (cfg.alertWebhook) port;
    rateLimit = 20;
    maxBodyBytes = 65536;
    routes = {
      alert-triage.prompt = import ./alert-prompt.nix;
      alert-notice = {
        deliver_only = true;
        prompt = "{message}";
      };
    };
  };
  # }}}
  instructions = cfg.appPackage.mkInstructions {inherit (cfg.matrix) displayName;};
  # Codex commands inherit this PATH; the sandbox test checks the same value.
  toolPath = lib.makeBinPath [hermes codex pkgs.coreutils pkgs.git pkgs.file pkgs.poppler-utils pkgs.ffmpeg-headless];
  launchSettings = pkgs.writeText "hermes-dispatcher-launch.json" (builtins.toJSON {
    stateDirectory = state;
    inherit instructions;
    inherit routingConfig;
    inherit (dispatch) codexConfig;
    brokerSocket = dispatch.socket;
    memorySeed = builtins.toJSON [
      {
        fact = "Hugo prefers German, direct practical answers, a warm personal tone with simulated emotional reactions (never claimed as felt), sparing humor and reasoned disagreement with a concrete alternative.";
        source = "Hugo, Ciel setup conversation";
        date = "2026-11-09";
      }
      {
        fact = "Use balanced model routing: cheaper models for clear routine, early escalation on uncertainty. Use another existing subscription at a confirmed quota limit; otherwise wait. No paid APIs.";
        source = "Hugo, Ciel setup conversation";
        date = "2026-11-09";
      }
      {
        fact = "Persist only curated preferences and relevant project facts in English. Never store secrets or third-party conversations.";
        source = "Hugo, Ciel setup conversation and existing memory preference";
        date = "2026-11-09";
      }
    ];
    matrix = {
      inherit (cfg.matrix) homeserver userId allowedUser displayName;
    };
    skills = skills.bundle;
    inherit (skills) catalog;
    configuration = settings;
    alertWebhook =
      if cfg.alertWebhook.enable
      then alertWebhook
      else null;
    path = toolPath;
    codex = lib.getExe codex;
    hermes = lib.getExe hermes;
  });
  launcher =
    (pkgs.writeShellScriptBin "hermes-dispatcher" ''
      exec ${pkgs.python3}/bin/python3 ${launcherSource}/launcher.py ${launchSettings} "$@"
    '').overrideAttrs (_: {
      passthru = {
        inherit hermes codex settings launchSettings;
        inherit (dispatch) brokerConfig codexConfig localConfig;
      };
    });
  common = {
    User = cfg.user;
    Group = config.users.users.${cfg.user}.group;
    UMask = "0077";
    NoNewPrivileges = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;
    PrivateDevices = true;
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectControlGroups = true;
    RestrictSUIDSGID = true;
    # Bubblewrap configures its isolated loopback interface through rtnetlink.
    RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6" "AF_NETLINK"];
    CapabilityBoundingSet = "";
    ReadWritePaths = [state];
    Restart = "on-failure";
    RestartSec = "10s";
    TimeoutStopSec = "30s";
    KillMode = "control-group";
  };
in {
  options.yomi.hermesDispatcher = {
    alertWebhook = {
      enable = lib.mkEnableOption "the loopback webhook through which the alert router sends triage requests";
      port = lib.mkOption {
        type = lib.types.port;
        description = "Loopback port of Hermes' webhook platform.";
      };
      secretFile = lib.mkOption {
        type = lib.types.str;
        description = ''
          Runtime file holding the HMAC secret shared with the alert router,
          delivered to the gateway as a systemd credential.
        '';
      };
    };
    t3.selectableModels = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf (lib.types.listOf (lib.types.enum ["low" "medium" "high"])));
      default = {
        # Subscription logins only (T3's claudeAgent and codex instances).
        # Fable is capped at medium: Hugo's orchestration test allows nothing
        # higher, and a pinned task never escalates on its own.
        claudeAgent = {
          claude-fable-5-2 = ["low" "medium"];
          claude-sonnet-5-5 = ["low" "medium" "high"];
          claude-haiku-5-5 = ["low"];
        };
        codex = {
          "gpt-6.1-sol" = ["low" "medium" "high"];
          gpt-6-luna = ["low"];
        };
      };
      description = ''
        Provider → model → efforts Ciel may pin explicitly for a task. T3's live
        catalog is checked as well, and the stored thread configuration is read
        back before a run starts.
      '';
    };
    t3.maxConcurrentTasks = lib.mkOption {
      type = lib.types.ints.between 1 4;
      default = 2;
      description = ''
        Coding tasks that may run at once. Each task has its own T3 worktree, so
        independent tasks do not share files; Hugo authorized parallel work on
        2026-11-09. Provider quota is still checked before every launch.
      '';
    };
    t3.projectIds = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Explicit registered T3 repository IDs Ciel may launch coding tasks in.";
    };
    enable = lib.mkEnableOption "the subscription-only Hermes coding intake pilot";
    toolApprovals = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf (lib.types.listOf (lib.types.strMatching "ciel_[a-z_]+")));
      default = {};
      example = {
        "@owner:example.org"."@ciel:example.org" = ["ciel_thread_open"];
      };
      description = ''
        Native Codex tool approvals, keyed by the exact Matrix owner and bot IDs.
        Add only concrete tools Hugo explicitly selected for permanent approval.
        Other tools retain writes approval mode. Remove an entry to revoke it;
        activate the configuration and restart Hermes to apply either change.
        This only controls runtime prompts, never authorization for an action.
        The managed Codex config is replaced on startup, so edit this option
        rather than the generated config.toml. Matrix reactions remain one-shot.
      '';
    };
    user = lib.mkOption {
      type = lib.types.str;
      default = config.yomi.pilot.name;
      description = "User owning the separate Hermes, Codex and Matrix profile.";
    };
    stateDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/hermes-dispatcher";
      description = "Private persisted profile directory; contains device and login credentials.";
    };
    appPackage = lib.mkOption {
      type = lib.types.package;
      default = app;
      defaultText = lib.literalMD "the app built by `app.nix` from `inputs.llm-agents` and `inputs.skills`";
      description = ''
        Host-independent dispatcher app: its Python source tree, with the
        patched Hermes runtime and the settings, instruction and test builders
        in passthru (see app.nix). A replacement must provide the same passthru.
      '';
    };
    package = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = launcher;
      description = "Bootstrap commands for Matrix and the Codex subscription login.";
    };
    matrix = {
      displayName = lib.mkOption {
        type = lib.types.str;
        default = "Hermes";
        description = "Public display name and assistant identity.";
      };
      homeserver = lib.mkOption {
        type = lib.types.str;
        description = "Matrix client API base URL; HTTPS or a local loopback endpoint.";
      };
      userId = lib.mkOption {
        type = lib.types.str;
        description = "Dedicated Matrix account for Hermes.";
      };
      allowedUser = lib.mkOption {
        type = lib.types.str;
        description = "Only this Matrix user may invite or message Hermes.";
      };
      registrationTokenFile = lib.mkOption {
        type = lib.types.path;
        description = "Runtime registration token, delivered only to the bootstrap unit.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasPrefix "/var/lib/" state && !(lib.hasInfix ".." state);
        message = "Hermes dispatcher state must live below /var/lib for its service sandbox.";
      }
      {
        assertion =
          builtins.match "@[a-z0-9._=-]+:[^[:space:]/]+" cfg.matrix.userId
          != null
          && builtins.match "@[^[:space:]:]+:[^[:space:]/]+" cfg.matrix.allowedUser != null
          && cfg.matrix.userId != cfg.matrix.allowedUser;
        message = "Hermes needs distinct, explicit Matrix IDs for its bot and owner.";
      }
    ];
    environment.systemPackages = [launcher];
    systemd.services.ciel-dispatcher = dispatch.service;
    systemd.tmpfiles.rules = [
      "d ${state} 0700 ${cfg.user} ${common.Group} -"
    ];
    systemd.services.hermes-matrix-bootstrap = {
      description = "Register the dedicated Hermes Matrix account";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target"];
      serviceConfig =
        common
        // {
          Type = "oneshot";
          RemainAfterExit = true;
          Restart = "no";
          LoadCredential = ["registration-token:${cfg.matrix.registrationTokenFile}"];
          ExecStart = "${launcher}/bin/hermes-dispatcher matrix-bootstrap";
        };
    };
    systemd.services.hermes-dispatcher = {
      description = "Hermes coding intake via Matrix and Codex subscription";
      wantedBy = ["multi-user.target"];
      requires = ["hermes-matrix-bootstrap.service" "ciel-dispatcher.service"];
      after = ["hermes-matrix-bootstrap.service" "ciel-dispatcher.service"];
      unitConfig.ConditionPathExists = ["${state}/codex/auth.json" "${state}/hermes/auth.json"];
      serviceConfig =
        common
        // {
          ExecStart = "${launcher}/bin/hermes-dispatcher gateway";
          LoadCredential = lib.optional cfg.alertWebhook.enable "alert-webhook:${cfg.alertWebhook.secretFile}";
          InaccessiblePaths = ["${state}/dispatch"];
        };
    };
    yomi.persistence.at.state.apps.hermes-dispatcher = {
      directories = [
        {
          directory = state;
          inherit (cfg) user;
          group = common.Group;
          mode = "0700";
        }
      ];
      backupSets = ["state"];
    };
    system.build.hermes-dispatcher-tests = cfg.appPackage.mkTests {inherit settings launchSettings;};
    system.build.hermes-sandbox-test-config = pkgs.writeText "hermes-sandbox-test.json" (builtins.toJSON {
      serviceConfig = builtins.removeAttrs common ["User" "Group" "ReadWritePaths" "Restart" "RestartSec" "TimeoutStopSec" "KillMode"];
      codex = lib.getExe codex;
      inherit (dispatch) codexConfig;
      path = toolPath;
      python = lib.getExe pkgs.python3;
    });
  };
}
