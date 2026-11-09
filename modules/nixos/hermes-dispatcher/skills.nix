{
  pkgs,
  lib,
  inputs,
}: let
  skillLib = import (inputs.skills + "/nix/lib.nix") {inherit lib;};
  compatible = skillLib.forHarness "codex" (skillLib.readSkills (inputs.skills + "/skills"));
  bundle = pkgs.linkFarm "hermes-yomi-skills" (lib.mapAttrsToList (name: skill: {
      inherit name;
      inherit (skill) path;
    })
    compatible);
  catalog =
    pkgs.runCommand "hermes-yomi-skill-catalog" {
      nativeBuildInputs = [(pkgs.python3.withPackages (p: [p.pyyaml]))];
    } ''
      python3 - ${bundle} "$out" <<'PY'
      from pathlib import Path
      import sys
      import yaml

      root = Path(sys.argv[1])
      entries = ["Available skills from Hugo's skill repository:"]
      for skill in sorted(root.iterdir()):
          path = skill / "SKILL.md"
          metadata = yaml.safe_load(path.read_text().split("---", 2)[1])
          description = " ".join(str(metadata["description"]).split())
          entries.append(f"- {metadata['name']}: {description} (read {path})")
      Path(sys.argv[2]).write_text("\n".join(entries) + "\n")
      PY
    '';
in {
  inherit bundle catalog;
  unslop = builtins.readFile (compatible.unslop.path + "/SKILL.md");
}
