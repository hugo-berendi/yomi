{config, ...}: {
  stylix.targets.kitty = {
    enable = true;
    variant256Colors = true;
  };

  programs.kitty = {
    enable = true;
    shellIntegration.enableFishIntegration = true;
    font = {
      name = config.stylix.fonts.monospace.name;
      size = config.stylix.fonts.sizes.terminal;
    };
    settings = {
      window_padding_width = 6;

      bold_font = "auto";
      italic_font = "auto";
      bold_italic_font = "auto";

      tab_bar_edge = "bottom";
      tab_bar_style = "powerline";
      tab_powerline_style = "angled";
    };
    extraConfig = ''
      background_opacity = ${builtins.toString config.stylix.opacity.terminal};
    '';
  };
}
