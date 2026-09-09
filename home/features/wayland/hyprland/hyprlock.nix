{
  pkgs,
  config,
  ...
}: let
  gravatar = pkgs.callPackage (import ../../../../common/avatar.nix) {};
  shell = config.yomi.shellTheme;
in {
  programs.hyprlock = {
    enable = true;
    importantPrefixes = [];
    settings = {
      general = {
        disable_loading_bar = true;
        grace = 1;
        hide_cursor = true;
      };
      background = {
        path = toString config.stylix.image;

        blur_passes = config.yomi.theming.blur.passes;
        blur_size = config.yomi.theming.blur.size;
        noise = 0.008;
        contrast = config.yomi.theming.blur.contrast;
        brightness = 0.72;
        vibrancy = 0.12;
      };

      image = {
        path = "${gravatar}/avatar.png";
        size = 128;
        rounding = -1;
        border_size = config.yomi.theming.rounding.size;
        border_color = shell.palette.accent;

        position = "0, 150";
        halign = "center";
        valign = "center";
      };

      input-field = {
        size = "300, 54";
        outline_thickness = config.yomi.theming.rounding.size;
        dots_size = 0.22;
        dots_spacing = 0.22;
        dots_center = true;
        dots_rounding = -1;
        outer_color = shell.palette.accent;
        inner_color = shell.rgba "background" shell.opacity.elevated;
        font_color = shell.palette.textStrong;
        fade_on_empty = false;
        fade_timeout = 1000;
        placeholder_text = "<span foreground='${shell.palette.muted}'>Password</span>";
        rounding = config.yomi.theming.rounding.radius;
        check_color = shell.palette.success;
        fail_color = shell.palette.critical;
        fail_text = "<i>$FAIL <b>($ATTEMPTS)</b></i>";
        fail_timeout = 2000;

        position = "0, 25";
        halign = "center";
        valign = "center";
      };

      label = [
        {
          text = "cmd[update:1000] date +'%H:%M'";
          color = shell.palette.textStrong;
          font_family = config.stylix.fonts.serif.name;
          font_size = 72;
          position = "0, -180";
          halign = "center";
          valign = "top";
        }
        {
          text = "cmd[update:60000] date +'%A, %d %B'";
          color = shell.palette.muted;
          font_family = config.stylix.fonts.sansSerif.name;
          font_size = 18;
          position = "0, -270";
          halign = "center";
          valign = "top";
        }
      ];
    };
    extraConfig = "";
  };
}
