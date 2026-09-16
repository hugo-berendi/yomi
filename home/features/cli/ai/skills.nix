{
  lib,
  inputs,
  ...
}: let
  skillsSource = "${inputs.skills}/skills";
  skillNames = builtins.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir skillsSource));

  skillFile = destDir: name: {
    name = "${destDir}/${name}/SKILL.md";
    value.source = "${skillsSource}/${name}/SKILL.md";
  };
in {
  # Skills always come from https://git.hugo-berendi.de/hugo-berendi/skills,
  # never authored here. Bump with `just bump-common`.
  xdg.configFile = lib.listToAttrs (map (skillFile "opencode/skills") skillNames);
  home.file = lib.listToAttrs (map (skillFile ".claude/skills") skillNames);
}
