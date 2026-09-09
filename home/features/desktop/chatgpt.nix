{
  config,
  pkgs,
  ...
}: {
  home.packages = [pkgs.chatgpt];

  yomi.persistence.at.state.apps.chatgpt.directories = [
    "${config.home.homeDirectory}/.codex"
    "${config.xdg.configHome}/ChatGPT"
  ];

  yomi.persistence.at.cache.apps.chatgpt.directories = [
    "${config.xdg.cacheHome}/chatgpt"
  ];
}
