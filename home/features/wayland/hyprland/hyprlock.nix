{
  pkgs,
  config,
  ...
}: let
  gravatar = pkgs.callPackage (import ../../../../common/avatar.nix) {};
in {
  programs.hyprlock = {
    enable = true;
    importantPrefixes = [];
    settings = {
      general = {};
      background = {
        path = toString config.stylix.image;

        blur_passes = 1;
        blur_size = 7;
        noise = 0.0117;
        contrast = 0.8916;
        brightness = 0.8172;
        vibrancy = 0.1696;
        vibrancy_darkness = 0.0;
      };

      image = {
        path = "${gravatar}/avatar.png";
        size = 150;
        rounding = -1;
        border_size = 4;
        border_color = "rgb(${config.yomi.theming.colors.rgb "base0D"})";
        rotate = 0;
        reload_time = -1;
        reload_cmd = "";

        position = "0, 200";
        halign = "center";
        valign = "center";
      };

      input-field = {
        size = "200, 50";
        outline_thickness = 3;
        dots_size = 0.33;
        dots_spacing = 0.15;
        dots_center = false;
        dots_rounding = -1;
        outer_color = "rgb(${config.yomi.theming.colors.rgb "base0D"})";
        inner_color = "rgb(${config.yomi.theming.colors.rgb "base01"})";
        font_color = "rgb(${config.yomi.theming.colors.rgb "base06"})";
        fade_on_empty = false;
        fade_timeout = 1000;
        placeholder_text = "<span foreground='#${config.lib.stylix.colors.withHashtag.base06}' style='italic'>Input Password...</span>";
        hide_input = false;
        rounding = -1;
        check_color = "rgb(${config.yomi.theming.colors.rgb "base09"})";
        fail_color = "rgb(${config.yomi.theming.colors.rgb "base08"})";
        fail_text = "<i>$FAIL <b>($ATTEMPTS)</b></i>";
        fail_timeout = 2000;
        fail_transition = 300;
        capslock_color = -1;
        numlock_color = -1;
        bothlock_color = -1;
        invert_numlock = false;
        swap_font_color = false;

        position = "0, 20";
        halign = "center";
        valign = "center";
      };
    };
    extraConfig = "";
  };
}
