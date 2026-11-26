{
  inputs,
  config,
  lib,
  ...
}: let
  checkout = config.yomi.ai.skillsCheckout;
  # A skill's directory: from the pinned flake input, or live from the
  # checkout so an edit there takes effect without a rebuild.
  skillSource = name:
    if checkout == null
    then config.skills.source + "/${name}"
    else config.lib.file.mkOutOfStoreSymlink "${checkout}/skills/${name}";
  # Skills shared by Codex and OpenCode, excluding harness-specific ones.
  copilotSkills = lib.attrNames (lib.filterAttrs (_: harnesses: lib.elem "codex" harnesses && lib.elem "opencode" harnesses) config.skills.resolved);
  # Every skill link the skills module makes, as "<target dir>/<skill>".
  harnessSkills = lib.concatLists (lib.mapAttrsToList (harness: target:
    lib.optionals target.enable (map (name: {
      path = "${target.dir}/${name}";
      inherit name;
    }) (lib.attrNames (lib.filterAttrs (_: harnesses: lib.elem harness harnesses) config.skills.resolved))))
  config.skills.targets);
in {
  imports = [inputs.skills.homeModules.default];

  options.yomi.ai.skillsCheckout = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "/home/hugob/projects/ai-skills";
    description = ''
      A local checkout of the skills repository to link skills from instead of
      the pinned flake input, so edits take effect at once. Which skills exist
      and which harness gets them still comes from the pinned input: a new or
      renamed skill needs `just bump-skills` and a switch. Uncommitted work in
      the checkout goes live too.
    '';
  };

  config = {
    # Skills always come from https://git.hugo-berendi.de/hugo-berendi/skills,
    # never authored here. Which harness sees which skill is decided there, in
    # each SKILL.md's `harnesses` field; this only turns the module on. Bump
    # with `just bump-skills`.
    skills.enable = true;
    yomi.persistence.at.state.apps.t3code.directories = ["${config.home.homeDirectory}/.copilot"];
    home.file = lib.mkMerge [
      (lib.genAttrs' copilotSkills (name: lib.nameValuePair ".copilot/skills/${name}" {source = skillSource name;}))
      (lib.mkIf (checkout != null) (lib.listToAttrs (map (skill:
        lib.nameValuePair skill.path {source = lib.mkForce (skillSource skill.name);})
      harnessSkills)))
    ];
  };
}
