{
  pkgs,
  config,
  inputs,
  ...
}: {
  home.packages = [
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex
  ];

  yomi.persistence.at.state.apps.codex.directories = [
    "${config.home.homeDirectory}/.codex"
  ];
}
