{
  pkgs,
  config,
  inputs,
  ...
}: {
  home.packages = [
    (import ./codex-package.nix {inherit inputs pkgs;})
  ];

  yomi.persistence.at.state.apps.codex.directories = [
    "${config.home.homeDirectory}/.codex"
  ];
}
