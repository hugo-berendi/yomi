{inputs, ...}: {
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
      font-size = config.stylix.fonts.sizes.terminal;
      font-family = "Iosevka Term Nerd Font";
      theme = "cloudcore";
      background-opacity = config.stylix.opacity.terminal;
      background-blur-radius = 7;
    };
  };
}
