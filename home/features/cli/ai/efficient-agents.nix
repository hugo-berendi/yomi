{
  config,
  lib,
  pkgs,
  osConfig ? null,
  ...
}: let
  enabled = osConfig != null && osConfig.networking.hostName == "inari";
  policyFile = ./delegation-policy.md;
  policy = builtins.readFile policyFile;
  python = pkgs.python3.withPackages (p: [p.tomlkit]);
  toml = pkgs.formats.toml {};
  codexRole = toml.generate "codex-fast-task.toml" {
    model = "gpt-6-luna";
    model_reasoning_effort = "low";
    developer_instructions = policy + "\nComplete only the bounded assignment; do not spawn more agents. Return compact evidence.";
  };
  localModel = "llama-cpp/qwen3.6-35b-a3b";
  # Runs without --auto, so a request the permission rules would ask about is
  # rejected and the agent carries on without it.
  localTask = pkgs.writeShellApplication {
    name = "local-task";
    runtimeInputs = [config.programs.opencode.package];
    text = ''
      if [ "$#" -eq 0 ]; then
        echo "usage: local-task <task description>" >&2
        exit 2
      fi
      exec opencode run --standalone --agent local-task --model ${localModel} --title "local-task" -- "$*"
    '';
  };
in
  lib.mkIf enabled {
    home.file.".claude/agents/fast-task.md".text = ''
      ---
      name: fast-task
      description: Use for independent routine lookup, triage, mechanical changes and targeted tests.
      model: claude-haiku-5-5
      ---
      ${policy}
      Complete only the assigned task. Do not delegate again.
    '';
    home.file.".claude/agents/quick-review.md".text = ''
      ---
      name: quick-review
      description: A bounded independent review needing more reasoning than the fast worker.
      model: claude-sonnet-5-5
      ---
      ${policy}
      Review only the supplied scope; report concrete findings and evidence.
    '';
    # Student exposes Auto only; fixed hidden models fail instead of saving usage.
    programs.opencode.settings.agent = {
      fast-task = {
        description = "Bounded routine work using the available Copilot Auto router.";
        mode = "subagent";
        model = "github-copilot/auto";
        prompt = policy + "\nComplete only the assigned task; do not delegate again.";
      };
      quick-review = {
        description = "Bounded independent review using the available Copilot Auto router.";
        mode = "subagent";
        model = "github-copilot/auto";
        prompt = policy + "\nReview only the assigned scope; report concrete findings compactly.";
      };
      # "all" so `opencode run --agent local-task` can drive it directly, the
      # way Claude Code and Codex call it through the wrapper below.
      local-task = {
        description = "Simple bounded task on the local Qwen3.6 model: free but slow.";
        mode = "all";
        model = localModel;
        steps = 40;
        permission.task = "deny";
        prompt = ''
          You are a local worker that another coding agent handed one bounded task.
          Nobody can answer questions or approve requests during your run. Make
          reasonable assumptions and state them. Stay inside the current directory.
          Do only what was asked. Do not commit, push or start other agents.
          Finish with a compact report: what you did, the files you changed, the
          evidence (command output or file:line), and anything left unresolved.
        '';
      };
    };
    home.packages = [localTask];
    home.activation.efficientAgentRouting = lib.hm.dag.entryAfter ["linkGeneration"] ''
      run ${python}/bin/python3 ${./install-agent-routing.py} ${lib.escapeShellArg config.home.homeDirectory} ${policyFile} ${codexRole}
    '';
  }
