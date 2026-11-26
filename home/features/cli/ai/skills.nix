{
  inputs,
  config,
  lib,
  ...
}: {
  imports = [inputs.skills.homeModules.default];

  # Skills always come from https://git.hugo-berendi.de/hugo-berendi/skills,
  # never authored here. Which harness sees which skill is decided there, in
  # each SKILL.md's `harnesses` field; this only turns the module on. Bump
  # with `just bump-common`.
  skills.enable = true;
  yomi.persistence.at.state.apps.t3code.directories = ["${config.home.homeDirectory}/.copilot"];
  # Use skills shared by Codex and OpenCode, excluding harness-specific skills.
  home.file = lib.mapAttrs' (name: _:
    lib.nameValuePair ".copilot/skills/${name}" {
      source = config.skills.source + "/${name}";
    }) (lib.filterAttrs (_: harnesses: lib.elem "codex" harnesses && lib.elem "opencode" harnesses) config.skills.resolved);
}
