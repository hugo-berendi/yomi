{
  pkgs,
  config,
  ...
}: {
  home.packages = [pkgs.codex];

  yomi.persistence.at.state.apps.codex.directories = [
    "${config.home.homeDirectory}/.codex"
  ];
}
