{
  pkgs,
  lib,
  config,
  inputs,
  ...
}: let
  rosePineCursor = import ./rose-pine-cursor.nix {inherit pkgs;};
in {
  imports = [../global.nix ./hyprpaper.nix ./hyprlock.nix ./hypridle.nix];

  home.packages = with pkgs; [
    hyprcursor
    rosePineCursor
    inputs.pyprland.packages.${pkgs.system}.pyprland
  ];

  stylix.targets.hyprland.enable = false;
  wayland.windowManager.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    extraConfig = builtins.readFile ./hyprland.conf;

    systemd = {
      variables = ["--all"];
      enableXdgAutostart = true;
    };

    plugins = [
      # {{{ Plugins
      # inputs.hy3.packages.x86_64-linux.hy3
      # }}}
    ];

    settings = {
      # {{{ Decoration
      decoration = {
        rounding = config.yomi.theming.rounding.radius;
        active_opacity = 1;
        inactive_opacity = 1;

        blur = {
          enabled = config.yomi.theming.blur.enable;
          ignore_opacity = true;
          xray = false; # looks ugly
          size = config.yomi.theming.blur.size;
          passes = config.yomi.theming.blur.passes;
          contrast = config.yomi.theming.blur.contrast;
          brightness = config.yomi.theming.blur.brightness;
          noise = 0;
        };
      };

      general = {
        gaps_in = config.yomi.theming.gaps.inner;
        gaps_out = config.yomi.theming.gaps.outer;
        border_size = config.yomi.theming.rounding.size;
        "col.active_border" = config.yomi.theming.colors.colorToRgb "base0D";
        "col.inactive_border" = config.yomi.theming.colors.colorToRgb "base00";
        layout = "dwindle";

        allow_tearing = true;
      };
      # }}}
      # {{{ Monitors
      # Configure monitor properties
      monitor = lib.forEach config.yomi.monitors (
        m:
          lib.concatStringsSep "," [
            m.name
            "${toString m.width}x${toString m.height}@${toString m.refreshRate}"
            "${toString m.x}x${toString m.y}"
            "1"
          ]
      );

      # Map monitors to workspaces
      workspace =
        lib.lists.concatMap (
          m: lib.lists.optional (m.workspace != null) "${m.name},${m.workspace}"
        )
        config.yomi.monitors;
      # }}}
      # {{{ autostart
      # Without this, xdg-open doesn't work
      exec = ["systemctl --user import-environment PATH && systemctl --user restart xdg-desktop-portal.service"];
      exec-once = [
        "${config.yomi.settings.terminal-cmd} & zen & vesktop & spotify & obsidiantui & pypr & xwaylandvideobridge"
        "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
        # "wl-paste --type text --watch cliphist store" # Stores only text data
        # "wl-paste --type image --watch cliphist store" # Stores only image data
        "ln -sf ${pkgs.fish}/bin/fish /usr/bin/fish"
      ];
      # }}}

      # {{{ Keybindings
      "$mod" = "SUPER";
      bind =
        [
          # {{{ misc keybinds
          "$mod, C, exec, cliphist list | anyrun --plugins ${inputs.anyrun.packages.${pkgs.system}.stdin}/lib/libstdin.so | cliphist decode | wl-copy"

          # }}}
          # {{{ pyprland plugins
          "$mod, V, exec, pypr toggle volume"
          "$mod Shift, Return, exec, pypr toggle term"
          "$mod, Y, exec, pypr attach"
          # }}}
          # {{{ control media
          ", XF86AudioMute, exec, volume --toggle"
          ", XF86AudioStop, exec, volume --stop"
          ", XF86AudioPrev, exec, volume --previous"
          ", XF86AudioNext, exec, volume --next"
          ", XF86AudioPlay, exec, volume --play-pause"
          # }}}
          # {{{ Execute external things
          "$mod, Space, exec, $menu"
          "$mod, T, exec, wl-ocr"
          "$mod SHIFT, T, exec, wl-qr"
          "$mod CONTROL, T, exec, hyprpicker | wl-copy && notify-send 'Copied color $(wp-paste)'" # Color picker
          "$mod, B, exec, wlsunset-toggle" # Toggle blue light filter thingy
          "bind = $mod, Return, exec, ${config.yomi.settings.terminal}"
          # }}}
          # {{{ Screenshotting
          "$mod, PRINT, exec, grimblast --notify copysave area"
          "$mod SHIFT, PRINT, exec, grimblast --notify copysave active"
          "$mod CONTROL, PRINT, exec, grimblast --notify copysave screen"
          # }}}
          # {{{ Power
          "$mod, Escape, exec, wlogout"
          # }}}
        ]
        ++ (
          # workspaces
          # binds $mod + [shift +] {1..10} to [move to] workspace {1..10}
          builtins.concatLists (
            builtins.genList (
              i: let
                ws =
                  if i == 0
                  then 10
                  else i + 1;
              in [
                "$mod, code:1${toString i}, workspace, ${toString ws}"
                "$mod SHIFT, code:1${toString i}, movetoworkspace, ${toString ws}"
              ]
            )
            10
          )
        );
      # {{{ binds that repeat when held
      binde = [
        # {{{ control volume
        ", XF86AudioRaiseVolume, exec, volume --inc"
        ", XF86AudioLowerVolume, exec, volume --dec"
        # }}}
        # {{{ control backlight
        ", XF86MonBrightnessDown, exec, backlight --dec"
        ", XF86MonBrightnessUp, exec, backlight --inc"
        # }}}
      ];
      # }}}
      # {{{ Mouse move/resize
      # Move/resize windows with mod + LMB/RMB and dragging
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];
      # }}}
      # {{{ windowrules
      windowrule = [
        # {{{ Automatically move stuff to workspaces
        "workspace 2 silent, title:^(.*Zen Browser.*)$"
        "workspace 3 silent, title:^(.*((Disc|WebC|Venc)ord)|Vesktop.*)$"
        "workspace 3 silent, title:^(.*Element.*)$"
        "workspace 5 silent, title:^(.*(S|s)pot(ify)?.*)$"
        "workspace 4 silent, class:^(.*Obsidian.*)$"
        "workspace 4 silent, title:^(.*stellar-sanctum)$"
        "workspace 4 silent, class:^(org\.wezfurlong\.wezterm\.obsidian)$"
        "workspace 8 silent, class:^(org\.wezfurlong\.wezterm\.smos)$"
        # }}}
        # {{{ xwaylandvideobridge
        "opacity 0.0 override, class:^(xwaylandvideobridge)$"
        "noanim, class:^(xwaylandvideobridge)$"
        "noinitialfocus, class:^(xwaylandvideobridge)$"
        "maxsize 1 1, class:^(xwaylandvideobridge)$"
        "noblur, class:^(xwaylandvideobridge)$"
        # }}}
        # {{{ Idleinhibit rules
        # - while firefox is fullscreen
        "idleinhibit fullscreen, title:^(.*Zen Browser.*)$"
        # - while watching videos
        "idleinhibit focus, class:^(mpv|.+exe)$"
        "idleinhibit focus, title:^(.*Zen Browser.*)$, title:^(.*YouTube.*)$"
        # }}}
      ];
      # }}}
      # }}}
    };
  };

  services.cliphist = {
    enable = true;
    package = pkgs.cliphist;
    allowImages = true;
    systemdTargets = ["graphical-session.target"];
  };

  home.file.".config/hypr/pyprland.toml".text =
    /*
    toml
    */
    ''
      [pyprland]
        plugins = ["scratchpads"]

      [scratchpads.term]
        animation = "fromTop"
        command = "foot -a foot-dropterm"
        class = "foot-dropterm"
        size = "75% 60%"
        margin = 50

      [scratchpads.volume]
        animation = "fromRight"
        command = "pwvucontrol"
        class = "com.saivert.pwvucontrol"
        size = "20% 90%"
        unfocus = "hide"
        lazy = true
    '';
}
