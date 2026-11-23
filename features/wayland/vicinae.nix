{
  config,
  lib,
  pkgs,
  ...
}: let
  shell = config.yomi.shellTheme;
  variant = config.stylix.polarity;
in {
  programs.vicinae = {
    enable = true;
    package = pkgs.vicinae;

    systemd = {
      enable = true;
      autoStart = true;
      target = "graphical-session.target";
    };

    settings = {
      close_on_focus_loss = true;
      consider_preedit = true;
      pop_to_root_on_close = true;
      search_files_in_root = false;
      favicon_service = "twenty";

      font = {
        normal = {
          family = config.stylix.fonts.sansSerif.name;
          size = config.stylix.fonts.sizes.applications;
        };
      };

      launcher_window = {
        opacity = shell.opacity.elevated;
        layer_shell.enabled = true;
      };

      theme = {
        dark.name = "yomi";
        light.name = "yomi";
      };
    };

    themes.yomi = {
      meta = {
        version = 1;
        name = "Yomi";
        description = "Semantic theme generated from the active Stylix scheme";
        inherit variant;
        inherits = "vicinae-${variant}";
      };

      colors = {
        core = {
          background = shell.palette.background;
          foreground = shell.palette.text;
          secondary_background = shell.palette.surface;
          border = shell.palette.surfaceRaised;
          accent = shell.palette.accent;
        };

        accents = {
          blue = shell.palette.accent;
          green = shell.palette.success;
          magenta = shell.palette.secondary;
          orange = shell.palette.warning;
          purple = shell.palette.secondary;
          red = shell.palette.critical;
          yellow = shell.palette.attention;
          cyan = shell.palette.info;
        };
      };
    };
  };

  yomi.persistence.at.state.apps.vicinae.directories = [
    "${config.xdg.dataHome}/vicinae"
  ];

  yomi.persistence.at.cache.apps.vicinae.directories =
    lib.optional
    (config.xdg.cacheHome != null)
    "${config.xdg.cacheHome}/vicinae";
}
