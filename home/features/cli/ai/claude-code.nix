{
  pkgs,
  config,
  inputs,
  ...
}: {
  home.packages = [
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
  ];

  yomi.persistence.at.state.apps.claude-code = {
    directories = ["${config.home.homeDirectory}/.claude"];
    files = ["${config.home.homeDirectory}/.claude.json"];
  };
}
