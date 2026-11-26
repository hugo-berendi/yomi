{
  config,
  lib,
  pkgs,
  osConfig ? null,
  ...
}: let
  enabled = osConfig != null && osConfig.networking.hostName == "inari";
  models = config.yomi.ai.models;
  policy = config.yomi.ai.instructions.delegation.text;
  python = pkgs.python3.withPackages (p: [p.tomlkit]);
  toml = pkgs.formats.toml {};
  codexRole = toml.generate "codex-fast-task.toml" {
    model = models.codex.cheap;
    model_reasoning_effort = models.codex.cheapEffort;
    developer_instructions = policy + "\nComplete only the bounded assignment; do not spawn more agents. Return compact evidence.";
  };
in
  lib.mkIf enabled {
    yomi.ai.instructions.delegation.enable = true;
    home.file.".claude/agents/fast-task.md".text = ''
      ---
      name: fast-task
      description: Use for independent routine lookup, triage, mechanical changes and targeted tests.
      model: ${models.claude.cheap}
      ---
      ${policy}
      Complete only the assigned task. Do not delegate again.
    '';
    home.file.".claude/agents/quick-review.md".text = ''
      ---
      name: quick-review
      description: A bounded independent review needing more reasoning than the fast worker.
      model: ${models.claude.review}
      ---
      ${policy}
      Review only the supplied scope; report concrete findings and evidence.
    '';
    home.activation.efficientAgentRouting = lib.hm.dag.entryAfter ["linkGeneration"] ''
      run ${python}/bin/python3 ${./install-codex-agents.py} ${lib.escapeShellArg config.home.homeDirectory} ${codexRole} ${lib.escapeShellArg models.codex.cheap} ${lib.escapeShellArg models.codex.cheapEffort}
    '';
  }
