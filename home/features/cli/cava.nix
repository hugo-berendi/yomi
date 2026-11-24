{config, ...}: {
  programs.cava = {
    enable = false;
    settings = {
      general.framerate = 60;
      input.method = "pipewire";
      smoothing.noise_reduction = 88;
      color = {
        background = "'${config.lib.stylix.colors.withHashtag.base01}'";
        foreground = "'${config.lib.stylix.colors.withHashtag.base0D}'";
      };
    };
  };
}
