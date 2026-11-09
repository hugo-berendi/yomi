{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.yomi.hermesDispatcher;
  system = pkgs.stdenv.hostPlatform.system;
  hermes = import ./package.nix {
    inherit pkgs;
    upstream = inputs.llm-agents.packages.${system}.hermes-agent;
  };
  codex = import ../../../home/features/cli/ai/codex-package.nix {inherit inputs pkgs;};
  skills = import ./skills.nix {inherit pkgs lib inputs;};
  state = cfg.stateDirectory;
  stt = import ./stt.nix {inherit pkgs;};
  routes = {
    routine = {
      model = "gpt-6-luna";
      effort = "low";
    };
    standard = {
      model = "gpt-6.1-sol";
      effort = "medium";
    };
    complex = {
      model = "gpt-6.1-sol";
      effort = "high";
    };
  };
  routingConfig = pkgs.writeText "ciel-routing.json" (builtins.toJSON {
    baseline = routes.standard;
    inherit routes;
  });
  dispatch = import ./dispatch.nix {inherit config lib pkgs inputs state skills launcherSource routes;};
  settings = pkgs.writeText "hermes-dispatcher-config.yaml" (builtins.toJSON {
    model = {
      provider = "openai-codex";
      default = "gpt-6.1-sol";
      openai_runtime = "codex_app_server";
    };
    agent = {
      reasoning_effort = "medium";
      max_iterations = 20;
    };
    fallback_providers = [];
    auth.adopt_external_logins = false;
    kanban = {
      dispatch_in_gateway = false;
      review_dispatch = false;
    };
    max_concurrent_sessions = 1;
    platform_toolsets.matrix = [];
    stt = stt.settings;
    auxiliary =
      lib.recursiveUpdate
      (lib.genAttrs ["compression" "title_generation" "background_review" "vision" "web_extract"] (name: {
        provider = "codex";
        model = "gpt-6-luna";
        reasoning_effort =
          if name == "compression"
          then "medium"
          else "low";
        fallback_chain = [];
      }))
      {
        title_generation = {
          enabled = false;
          model_upgrade_enabled = false;
        };
        background_review.enabled = false;
      };
    terminal.cwd = "${state}/home";
    memory = {
      memory_enabled = false;
      user_profile_enabled = false;
    };
    plugins.entries = {
      matrix-platform.enabled = true;
      signal-platform.enabled = false;
    };
    skills.external_dirs = ["${skills.bundle}"];
  });
  instructions = import ./instructions.nix {
    inherit pkgs skills;
    inherit (cfg.matrix) displayName;
  };
  launchSettings = pkgs.writeText "hermes-dispatcher-launch.json" (builtins.toJSON {
    stateDirectory = state;
    inherit instructions;
    inherit routingConfig;
    inherit (dispatch) codexConfig;
    brokerSocket = dispatch.socket;
    memorySeed = builtins.toJSON [
      {
        fact = "Hugo prefers German, direct practical answers, warm dry humor and reasoned disagreement with a concrete alternative.";
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
    path = lib.makeBinPath [hermes codex pkgs.coreutils pkgs.git];
    codex = lib.getExe codex;
    hermes = lib.getExe hermes;
  });
  launcher =
    (pkgs.writeShellScriptBin "hermes-dispatcher" ''
      exec ${pkgs.python3}/bin/python3 ${launcherSource}/launcher.py ${launchSettings} "$@"
    '').overrideAttrs (_: {
      passthru = {
        inherit hermes settings launchSettings;
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
  launcherSource = pkgs.runCommand "hermes-dispatcher-source" {} ''
    mkdir -p "$out"
    cp ${./launcher.py} "$out/launcher.py"
    cp ${./matrix_bootstrap.py} "$out/matrix_bootstrap.py"
    cp ${./matrix_profile.py} "$out/matrix_profile.py"
    ${lib.concatMapStringsSep "\n" (name: "cp ${./. + "/${name}.py"} \"$out/${name}.py\"") ["broker_client" "ciel_routing" "dispatch_core" "dispatch_service" "dispatch_store" "local_tools" "mcp_server" "t3_rpc" "t3_mcp" "t3_mcp_auth" "t3_backend" "task_policy" "provider_policy" "quota_recovery" "matrix_rooms" "pr_verification" "task_followup" "task_scheduler" "task_notices" "project_memory" "ciel_watch"]}
  '';
in {
  options.yomi.hermesDispatcher = {
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
    system.build.hermes-dispatcher-tests =
      pkgs.runCommand "hermes-dispatcher-tests" {
        nativeBuildInputs = [pkgs.python3];
      } ''
        cp ${launcherSource}/*.py .
        ${lib.concatMapStringsSep "\n" (name: "cp ${./. + "/${name}"} ${lib.escapeShellArg name}") (lib.filter (name: lib.hasPrefix "test_" name && lib.hasSuffix ".py" name) (builtins.attrNames (builtins.readDir ./.)))}
        for site in ${hermes}/lib/python*/site-packages; do
          export CIEL_HERMES_SOURCE="$site"
        done
        export CIEL_HERMES_SETTINGS=${settings}
        python3 -m unittest discover -p 'test_*.py' -v
        touch "$out"
      '';
  };
}
