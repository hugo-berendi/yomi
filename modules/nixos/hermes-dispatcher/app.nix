# Hermes dispatcher application, independent of any host.
#
# Everything here is a function of pinned inputs only: the patched Hermes
# runtime, the dispatcher's Python sources, the Hermes settings and
# instructions it ships with, and the unit tests. The NixOS module in
# default.nix adds host facts (users, Matrix IDs, T3 paths, ports, sandbox)
# and consumes this through `yomi.hermesDispatcher.appPackage`, so the app and
# its tests evaluate without nixosConfigurations.inari.
{
  pkgs,
  lib,
  # llm-agents' hermes-agent, which package.nix patches.
  hermesAgent,
  # Source tree of the skills flake input (needs nix/lib.nix and skills/).
  skillsSource,
}: let
  hermes = import ./package.nix {
    inherit pkgs;
    upstream = hermesAgent;
  };
  skills = import ./skills.nix {
    inherit pkgs lib;
    inputs.skills = skillsSource;
  };
  stt = import ./stt.nix {inherit pkgs;};
  speech = import ./speech.nix {inherit pkgs;};
  # {{{ Routing
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
  # }}}
  # {{{ Hermes settings
  # `state` is the only deployment fact the Hermes config needs.
  mkSettings = {state}:
    pkgs.writeText "hermes-dispatcher-config.yaml" (builtins.toJSON {
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
      # Webhook turns get no Hermes tools either; Codex-side limits are in
      # ciel_webhook_policy.py.
      platform_toolsets.webhook = [];
      # The Matrix plugin registers display tier "medium", which posts a bubble
      # for every new tool call. Hugo reads Ciel's answers, not her tool log.
      # This gate covers tool bubbles only: clarify prompts, approvals and
      # subagent failure notices take separate paths and stay visible.
      display.platforms.matrix.tool_progress = "off";
      stt = stt.settings;
      tts = speech.settings;
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
  mkInstructions = {displayName}:
    import ./instructions.nix {
      inherit pkgs skills displayName;
    };
  # }}}
  # {{{ Tests
  testFiles = lib.filter (name: lib.hasPrefix "test_" name && lib.hasSuffix ".py" name) (builtins.attrNames (builtins.readDir ./.));
  # The host passes its real settings; the standalone check uses the fixture
  # below. test_instructions.py reads only `instructions` from launch settings.
  mkTests = {
    settings,
    launchSettings,
  }:
    pkgs.runCommand "hermes-dispatcher-tests" {
      nativeBuildInputs = [pkgs.python3];
    } ''
      cp ${source}/*.py .
      ${lib.concatMapStringsSep "\n" (name: "cp ${./. + "/${name}"} ${lib.escapeShellArg name}") testFiles}
      for site in ${hermes}/lib/python*/site-packages; do
        export CIEL_HERMES_SOURCE="$site"
      done
      export CIEL_HERMES_SETTINGS=${settings}
      export CIEL_LAUNCH_SETTINGS=${launchSettings}
      python3 -m unittest discover -p 'test_*.py' -v
      touch "$out"
    '';
  fixtureSettings = mkSettings {state = "/var/lib/hermes-dispatcher";};
  tests = mkTests {
    settings = fixtureSettings;
    launchSettings = pkgs.writeText "hermes-dispatcher-test-launch.json" (builtins.toJSON {
      instructions = mkInstructions {displayName = "Hermes";};
      inherit routingConfig;
      configuration = fixtureSettings;
    });
  };
  # }}}
  modules = ["broker_client" "ciel_routing" "dispatch_core" "dispatch_service" "dispatch_store" "local_tools" "mcp_server" "t3_rpc" "t3_mcp" "t3_mcp_auth" "t3_backend" "task_policy" "provider_policy" "quota_recovery" "matrix_rooms" "pr_verification" "task_followup" "task_scheduler" "task_notices" "project_memory" "ciel_watch" "runtime_approvals" "model_selection" "task_requests" "task_supplements" "task_solve" "task_blockers" "workspace_binding" "matrix_threads" "ciel_voice" "alert_webhook"];
  # The app package is the dispatcher's Python source tree; passthru carries
  # the runtime and builders the NixOS module needs. passthru does not enter
  # the derivation, so this store path matches the former launcherSource.
  source =
    pkgs.runCommand "hermes-dispatcher-source" {
      passthru = {
        inherit hermes skills stt speech routes routingConfig mkSettings mkInstructions mkTests tests;
      };
    } ''
      mkdir -p "$out"
      cp ${./launcher.py} "$out/launcher.py"
      cp ${./matrix_bootstrap.py} "$out/matrix_bootstrap.py"
      cp ${./matrix_profile.py} "$out/matrix_profile.py"
      ${lib.concatMapStringsSep "\n" (name: "cp ${./. + "/${name}.py"} \"$out/${name}.py\"") modules}
    '';
in
  source
