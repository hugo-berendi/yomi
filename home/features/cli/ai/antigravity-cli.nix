{
  pkgs,
  config,
  inputs,
  ...
}: {
  home.packages = [
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.antigravity-cli
  ];

  yomi.persistence.at.state.apps.antigravity-cli.directories = [
    "${config.home.homeDirectory}/.gemini"
  ];
}
