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
in
  lib.mkIf enabled {
    home.file.".claude/agents/fast-task.md".text = ''
      ---
      name: fast-task
      description: Use for independent routine lookup, triage, mechanical changes and targeted tests.
      model: haiku
      ---
      ${policy}
      Complete only the assigned task. Do not delegate again.
    '';
    home.file.".claude/agents/quick-review.md".text = ''
      ---
      name: quick-review
      description: A bounded independent review needing more reasoning than the fast worker.
      model: sonnet
      ---
      ${policy}
      Review only the supplied scope; report concrete findings and evidence.
    '';
    programs.opencode.settings.agent = {
      fast-task = {
        description = "Cheap routine lookup, triage, mechanical change or targeted test.";
        mode = "subagent";
        model = "github-copilot/claude-haiku-5.5";
        prompt = policy + "\nComplete only the assigned task; do not delegate again.";
      };
      quick-review = {
        description = "Bounded independent review requiring Sonnet-class reasoning.";
        mode = "subagent";
        model = "github-copilot/claude-sonnet-5.5";
        prompt = policy + "\nReview only the assigned scope; report concrete findings compactly.";
      };
    };
    home.activation.efficientAgentRouting = lib.hm.dag.entryAfter ["linkGeneration"] ''
      run ${python}/bin/python3 ${./install-agent-routing.py} ${lib.escapeShellArg config.home.homeDirectory} ${policyFile} ${codexRole}
    '';
  }
