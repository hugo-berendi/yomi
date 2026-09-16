{
  lib,
  inputs,
  ...
}: let
  skillsSource = "${inputs.skills}/skills";
  skillNames = builtins.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir skillsSource));

  skillDir = destDir: name: {
    name = "${destDir}/${name}";
    value.source = "${skillsSource}/${name}";
  };
in {
  # Skills always come from https://git.hugo-berendi.de/hugo-berendi/skills,
  # never authored here. Bump with `just bump-common`. Symlinking whole
  # directories, not just SKILL.md, so bundled scripts/templates travel too.
  xdg.configFile = lib.listToAttrs (map (skillDir "opencode/skills") skillNames);
  home.file = lib.listToAttrs (
    lib.concatMap (destDir: map (skillDir destDir) skillNames) [
      ".claude/skills"
      ".codex/skills"
      ".gemini/config/skills"
    ]
  );
}
