{
  inputs,
  config,
  pkgs,
  lib,
  ...
}: let
  skillInstructions = pkgs.writeText "agent-skill-instructions" ''
    Before starting a task, check the available skill names and descriptions.
    When a skill matches the task, read its SKILL.md and follow it automatically,
    without waiting for the user to name it. Follow explicit skill triggers,
    including skills that always apply. Load referenced resources only as needed.
    Use the current installed catalog rather than assuming a skill exists.
    If a relevant skill is unavailable, say so briefly and continue with the
    available tools. The user's instructions take precedence over skill guidance.
  '';
in {
  imports = [inputs.skills.homeModules.default];

  programs.opencode.settings.instructions = ["${skillInstructions}"];
  home.activation.agentSkillInstructions = lib.hm.dag.entryAfter ["linkGeneration"] ''
    run ${pkgs.python3}/bin/python3 ${./install-skill-instructions.py} ${lib.escapeShellArg config.home.homeDirectory} ${skillInstructions}
  '';

  # Skills always come from https://git.hugo-berendi.de/hugo-berendi/skills,
  # never authored here. Which harness sees which skill is decided there, in
  # each SKILL.md's `harnesses` field; this only turns the module on. Bump
  # with `just bump-common`.
  skills.enable = true;
}
