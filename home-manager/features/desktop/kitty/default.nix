{
  inputs,
  upkgs,
  config,
  ...
}: {
  programs.kitty = {
    enable = true;

    extraConfig = ''
      background_opacity 0.85

      window_padding_width 6

      font_family      ${config.stylix.fonts.monospace.name}
      bold_font        auto
      italic_font      auto
      bold_italic_font auto

      font_size 12.0

      tab_bar_edge bottom
      tab_bar_style powerline
      tab_powerline_style angled


    '';
  };
}
