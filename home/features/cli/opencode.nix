{
  inputs,
  pkgs,
  config,
  ...
}: {
  home.packages = [inputs.opencode-flake.packages.${pkgs.system}.default];

  yomi.persistence.at.state.apps.opencode.directories = ["${config.home.homeDirectory}/.local/share/opencode"];
}
