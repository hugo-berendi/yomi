{
  pkgs,
  config,
  ...
}: {
  home.packages = [pkgs.claude-code];

  yomi.persistence.at.state.apps.claude-code = {
    directories = ["${config.home.homeDirectory}/.claude"];
    files = ["${config.home.homeDirectory}/.claude.json"];
  };
}
