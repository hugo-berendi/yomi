{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.yomi.hermesDispatcher;
  system = pkgs.stdenv.hostPlatform.system;
  hermes = inputs.llm-agents.packages.${system}.hermes-agent;
  codex = import ../../../home/features/cli/ai/codex-package.nix {inherit inputs pkgs;};
  skills = import ./skills.nix {inherit pkgs lib inputs;};
  state = cfg.stateDirectory;
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
    auxiliary =
      lib.genAttrs ["compression" "title_generation" "background_review" "vision" "web_extract"] (_: {
        provider = "codex";
        model = "gpt-6.1-sol";
        reasoning_effort = "low";
        fallback_chain = [];
      })
      // {
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
      passthru = {inherit hermes settings launchSettings;};
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
    RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
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
  '';
in {
  options.yomi.hermesDispatcher = {
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
      requires = ["hermes-matrix-bootstrap.service"];
      after = ["hermes-matrix-bootstrap.service"];
      unitConfig.ConditionPathExists = ["${state}/codex/auth.json" "${state}/hermes/auth.json"];
      serviceConfig =
        common
        // {
          ExecStart = "${launcher}/bin/hermes-dispatcher gateway";
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
        cp ${./launcher.py} launcher.py
        cp ${./test_launcher.py} test_launcher.py
        cp ${./matrix_bootstrap.py} matrix_bootstrap.py
        cp ${./test_matrix_bootstrap.py} test_matrix_bootstrap.py
        cp ${./matrix_profile.py} matrix_profile.py
        cp ${./test_matrix_profile.py} test_matrix_profile.py
        python3 -m unittest -v test_launcher test_matrix_bootstrap test_matrix_profile
        touch "$out"
      '';
  };
}
