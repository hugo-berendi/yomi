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
        noise = 0.006;
        contrast = 1.05;
        brightness = 0.54;
        vibrancy = 0.24;
        vibrancy_darkness = 0.12;
      };

      shape = [
        {
          size = "440, 520";
          color = shell.rgba "surface" 0.78;
          rounding = 32;
          border_size = 1;
          border_color = shell.rgba "text" 0.12;
          shadow_passes = 5;
          shadow_size = 14;
          shadow_color = shell.rgba "background" 0.72;
          shadow_boost = 1.15;
          position = "72, 0";
          halign = "left";
          valign = "center";
        }
        {
          size = "5, 72";
          color = hyprColor shell.palette.accent;
          rounding = -1;
          position = "72, 150";
          halign = "left";
          valign = "center";
        }
      ];

      image = {
        path = "${gravatar}/avatar.png";
        size = 92;
        rounding = -1;
        border_size = 3;
        border_color = shell.rgba "accent" 0.9;
        shadow_passes = 2;
        shadow_size = 6;
        shadow_color = shell.rgba "background" 0.6;
        position = "120, -20";
        halign = "left";
        valign = "center";
      };

      input-field = {
        size = "340, 58";
        outline_thickness = 2;
        dots_size = 0.18;
        dots_spacing = 0.32;
        dots_center = true;
        dots_rounding = -1;
        dots_text_format = "●";
        outer_color = shell.rgba "accent" 0.72;
        inner_color = shell.rgba "surfaceRaised" 0.88;
        font_color = hyprColor shell.palette.textStrong;
        font_family = config.stylix.fonts.sansSerif.name;
        fade_on_empty = false;
        fade_timeout = 1000;
        placeholder_text = "<span foreground='${shell.palette.muted}'>󰌾  Passwort</span>";
        rounding = 18;
        check_color = hyprColor shell.palette.success;
        fail_color = hyprColor shell.palette.critical;
        capslock_color = hyprColor shell.palette.attention;
        fail_text = "<i>$FAIL · Versuch $ATTEMPTS</i>";
        fail_timeout = 2000;
        shadow_passes = 3;
        shadow_size = 8;
        shadow_color = shell.rgba "background" 0.5;
        position = "120, -130";
        halign = "left";
        valign = "center";
      };

      label = [
        {
          text = "cmd[update:1000] date +'%H:%M'";
          color = hyprColor shell.palette.textStrong;
          font_family = config.stylix.fonts.sansSerif.name;
          font_size = 82;
          position = "116, 150";
          halign = "left";
          valign = "center";
        }
        {
          text = "cmd[update:60000] date +'%A · %d. %B'";
          color = hyprColor shell.palette.muted;
          font_family = config.stylix.fonts.sansSerif.name;
          font_size = 16;
          position = "124, 82";
          halign = "left";
          valign = "center";
        }
        {
          text = "Willkommen zurück";
          color = hyprColor shell.palette.muted;
          font_family = config.stylix.fonts.sansSerif.name;
          font_size = 13;
          position = "230, -4";
          halign = "left";
          valign = "center";
        }
        {
          text = "$USER";
          color = hyprColor shell.palette.textStrong;
          font_family = config.stylix.fonts.sansSerif.name;
          font_size = 24;
          position = "228, -32";
          halign = "left";
          valign = "center";
        }
        {
          text = "󰌾  Passwort eingeben, um fortzufahren";
          color = hyprColor shell.palette.muted;
          font_family = config.stylix.fonts.sansSerif.name;
          font_size = 12;
          position = "124, -184";
          halign = "left";
          valign = "center";
        }
      ];
    };
    extraConfig = "";
  };
}
