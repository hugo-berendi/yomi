{
  inputs,
  config,
  ...
}: {
  yomi.settings = {
    terminal = "ghostty";
    terminal-cmd = "ghostty";
  };
  stylix.targets.ghostty.enable = true;
  programs.ghostty = {
    enable = true;
    package = inputs.ghostty-pkg.packages.x86_64-linux.default;
    enableFishIntegration = true;
    installVimSyntax = true;
    settings = {
      # font-size = config.stylix.fonts.sizes.terminal;
      # font-family = toString config.stylix.fonts.monospace.name;
      # theme = "rose-pine-moon";
      # background-opacity = config.stylix.opacity.terminal;
      # background-blur-radius = 7;
    };
  };
}
