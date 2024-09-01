{config, ...}: {
  programs.hyfetch = {
    enable = true;
    settings = {
      preset = "bisexual";
      mode = "rgb";
      light_dark = config.stylix.polarity;
      lightness = 0.68;
      color_align = {
        mode = "custom";
        custom_colors = {
          "2" = 0;
          "1" = 2;
        };
        fore_back = [];
      };
    };
  };
}
