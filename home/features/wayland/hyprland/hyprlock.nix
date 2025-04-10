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
      general = {
      };
      background = {
        path = toString config.stylix.image; # supports png, jpg, webp (no animations, though)

        # all these options are taken from hyprland, see https://wiki.hyprland.org/Configuring/Variables/#blur for explanations
        blur_passes = 1; # 0 disables blurring
        blur_size = 7;
        noise = 0.0117;
        contrast = 0.8916;
        brightness = 0.8172;
        vibrancy = 0.1696;
        vibrancy_darkness = 0.0;
      };

      image = {
        path = "${gravatar}/avatar.png";
        size = 150; # lesser side if not 1:1 ratio
        rounding = -1; # negative values mean circle
        border_size = 4;
        border_color = "rgb(${config.yomi.theming.colors.rgb "base0D"})";
        rotate = 0; # degrees, counter-clockwise
        reload_time = -1; # seconds between reloading, 0 to reload with SIGUSR2
        reload_cmd = ""; # command to get new path. if empty, old path will be used. don't run "follow" commands like tail -F

        position = "0, 200";
        halign = "center";
        valign = "center";
      };

      input-field = {
        size = "200, 50";
        outline_thickness = 3;
        dots_size = 0.33; # Scale of input-field height, 0.2 - 0.8
        dots_spacing = 0.15; # Scale of dots' absolute size, 0.0 - 1.0
        dots_center = false;
        dots_rounding = -1; # -1 default circle, -2 follow input-field rounding
        outer_color = "rgb(${config.yomi.theming.colors.rgb "base0D"})";
        inner_color = "rgb(${config.yomi.theming.colors.rgb "base01"})";
        font_color = "rgb(${config.yomi.theming.colors.rgb "base06"})";
        fade_on_empty = false;
        fade_timeout = 1000; # Milliseconds before fade_on_empty is triggered.
        placeholder_text = "<span foreground='#${config.lib.stylix.colors.withHashtag.base06}' style='italic'>Input Password...</span>"; # Text rendered in the input box when it's empty.
        hide_input = false;
        rounding = -1; # -1 means complete rounding (circle/oval)
        check_color = "rgb(${config.yomi.theming.colors.rgb "base09"})";
        fail_color = "rgb(${config.yomi.theming.colors.rgb "base08"})"; # if authentication failed, changes outer_color and fail message color
        fail_text = "<i>$FAIL <b>($ATTEMPTS)</b></i>"; # can be set to empty
        fail_timeout = 2000; # milliseconds before fail_text and fail_color disappears
        fail_transition = 300; # transition time in ms between normal outer_color and fail_color
        capslock_color = -1;
        numlock_color = -1;
        bothlock_color = -1; # when both locks are active. -1 means don't change outer color (same for above)
        invert_numlock = false; # change color if numlock is off
        swap_font_color = false; # see below

        position = "0, 20";
        halign = "center";
        valign = "center";
      };
    };
    extraConfig = ''
      # Add extra configuration here
    '';
  };
}
