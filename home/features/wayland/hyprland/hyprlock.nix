{
  pkgs,
  config,
  ...
}: let
  gravatar = pkgs.callPackage (import ../../../../common/avatar.nix) {};
  shell = config.yomi.shellTheme;
  hyprColor = config.yomi.theming.colors.hexToRgb;
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
        brightness = 0.64;
        vibrancy = 0.18;
      };

      image = {
        path = "${gravatar}/avatar.png";
        size = 112;
        rounding = -1;
        border_size = 4;
        border_color = hyprColor shell.palette.accent;
        shadow_passes = 2;
        shadow_size = 4;
        shadow_color = shell.rgba "background" 0.6;

        position = "0, 110";
        halign = "center";
        valign = "center";
      };

      input-field = {
        size = "340, 58";
        outline_thickness = config.yomi.theming.rounding.size;
        dots_size = 0.2;
        dots_spacing = 0.28;
        dots_center = true;
        dots_rounding = -1;
        dots_text_format = "●";
        outer_color = hyprColor shell.palette.accent;
        inner_color = shell.rgba "background" shell.opacity.elevated;
        font_color = hyprColor shell.palette.textStrong;
        font_family = config.stylix.fonts.sansSerif.name;
        fade_on_empty = false;
        fade_timeout = 1000;
        placeholder_text = "<span foreground='${shell.palette.muted}'>Password eingeben</span>";
        rounding = config.yomi.theming.rounding.radius;
        check_color = hyprColor shell.palette.success;
        fail_color = hyprColor shell.palette.critical;
        fail_text = "<i>$FAIL <b>($ATTEMPTS)</b></i>";
        fail_timeout = 2000;
        shadow_passes = 2;
        shadow_size = 4;
        shadow_color = shell.rgba "background" 0.6;

        position = "0, -5";
        halign = "center";
        valign = "center";
      };

      label = [
        {
          text = "cmd[update:1000] date +'%H:%M'";
          color = hyprColor shell.palette.textStrong;
          font_family = config.stylix.fonts.serif.name;
          font_size = 72;
          position = "0, -180";
          halign = "center";
          valign = "top";
        }
        {
          text = "cmd[update:60000] date +'%A, %d %B'";
          color = hyprColor shell.palette.muted;
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
