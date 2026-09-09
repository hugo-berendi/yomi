{
  pkgs,
  lib,
  config,
  inputs,
  upkgs,
  ...
}: let
  spotifyCmd =
    if config.programs.spicetify.enable
    then lib.getExe config.programs.spicetify.spicedSpotify
    else "spotify";
  vicinae = lib.getExe config.programs.vicinae.package;
  swayosd = lib.getExe' config.services.swayosd.package "swayosd-client";
in {
  # {{{ Imports
  imports = [
    ../global.nix
    ./hyprpaper.nix
    ./hyprlock.nix
    ./hypridle.nix
  ];
  # }}}
  # {{{ Packages
  home.packages = with pkgs; [
    hyprcursor
    inputs.rose-pine-hyprcursor.packages.${pkgs.stdenv.hostPlatform.system}.default
    qt6Packages.qt6ct
    inputs.pyprland.packages.${pkgs.stdenv.hostPlatform.system}.pyprland
    upkgs.hyprpolkitagent
  ];
  # }}}
  # {{{ Hyprland
  stylix.targets.hyprland.enable = false;
  wayland.windowManager.hyprland = {
    enable = true;
    configType = "hyprlang";

    package = pkgs.hyprland;
    portalPackage = null;

    extraConfig = builtins.readFile ./hyprland.conf;

    systemd = {
      variables = ["--all"];
      enableXdgAutostart = true;
    };

    settings = {
      # {{{ Decoration
      decoration = {
        rounding = config.yomi.theming.rounding.radius;
        active_opacity = 1;
        inactive_opacity = 1;

        blur = {
          enabled = config.yomi.theming.blur.passes > 0;
          ignore_opacity = true;
          xray = false;
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
      monitor =
        (lib.forEach config.yomi.monitors (
          m:
            lib.concatStringsSep "," [
              m.name
              "${toString m.width}x${toString m.height}@${toString m.refreshRate}"
              "${toString m.x}x${toString m.y}"
              "1"
            ]
        ))
        ++ [",preferred,auto,1"];

      workspace = let
        monitorWorkspaces =
          lib.lists.concatMap (
            m:
              if m.workspace != null
              then let
                startWs = lib.toInt m.workspace;
              in
                lib.genList (i: "${m.name},${toString (startWs + i)}") 5
              else []
          )
          config.yomi.monitors;
      in
        monitorWorkspaces;
      # }}}
      # {{{ Autostart
      exec = ["systemctl --user import-environment PATH && systemctl --user restart xdg-desktop-portal.service"];
      exec-once = [
        "${config.yomi.settings.terminal-cmd} & helium & vesktop & ${spotifyCmd} & obsidiantui & pypr"
        "command -v karere >/dev/null 2>&1 && karere || true"
        "command -v teams-for-linux >/dev/null 2>&1 && teams-for-linux || true"
        "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
        "ln -sf ${pkgs.fish}/bin/fish /usr/bin/fish"
        "systemctl --user start hyprpolkitagent"
      ];
      # }}}

      # {{{ Keybindings
      "$mod" = "SUPER";
      bind =
        [
          # {{{ pyprland plugins
          "$mod, A, exec, pypr toggle volume"
          "$mod Shift, Return, exec, pypr toggle term"
          "$mod, Y, exec, pypr attach"
          # }}}
          # {{{ control media
          ", XF86AudioMute, exec, ${swayosd} --output-volume mute-toggle"
          ", XF86AudioMicMute, exec, ${swayosd} --input-volume mute-toggle"
          ", XF86AudioStop, exec, ${lib.getExe pkgs.playerctl} stop"
          ", XF86AudioPrev, exec, ${lib.getExe pkgs.playerctl} previous"
          ", XF86AudioNext, exec, ${lib.getExe pkgs.playerctl} next"
          ", XF86AudioPlay, exec, ${lib.getExe pkgs.playerctl} play-pause"
          # }}}
          # {{{ Execute external things
          "$mod, Space, exec, ${vicinae} toggle"
          "$mod, V, exec, ${vicinae} deeplink vicinae://launch/clipboard/history"
          "$mod, N, exec, ${lib.getExe' config.services.swaync.package "swaync-client"} -t -sw"
          "$mod, T, exec, wl-ocr"
          "$mod SHIFT, T, exec, wl-qr"
          "$mod CONTROL, T, exec, hyprpicker | wl-copy && notify-send 'Copied color $(wp-paste)'"
          "$mod, B, exec, wlsunset-toggle"
          "$mod, Return, exec, ${config.yomi.settings.terminal}"
          # }}}
          # {{{ Screenshotting
          "$mod, PRINT, exec, grimblast --notify copysave area"
          "$mod SHIFT, PRINT, exec, grimblast --notify copysave active"
          "$mod CONTROL, PRINT, exec, grimblast --notify copysave screen"
          "$mod ALT, PRINT, exec, wl-immich"
          # }}}
          # {{{ Power
          "$mod, Escape, exec, caelestia shell drawers toggle session"
          # }}}
        ]
        ++ (
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
      binde = [
        # {{{ control volume
        ", XF86AudioRaiseVolume, exec, ${swayosd} --output-volume raise"
        ", XF86AudioLowerVolume, exec, ${swayosd} --output-volume lower"
        # }}}
        # {{{ control backlight
        ", XF86MonBrightnessDown, exec, ${swayosd} --brightness lower"
        ", XF86MonBrightnessUp, exec, ${swayosd} --brightness raise"
      ];
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];
      windowrule = [
        "workspace 2 silent, class:^(helium|helium-browser)$"
        "workspace 2 silent, title:^(.*Helium.*)$"
        "workspace 3 silent, title:^(.*((Disc|WebC|Venc)ord)|Vesktop.*)$"
        "workspace 3 silent, title:^(.*Element.*)$"
        "workspace 3 silent, class:^(teams-for-linux|teams|karere)$"
        "workspace 3 silent, title:^(.*(Teams|Karere|WhatsApp).*)$"
        "workspace 5 silent, title:^(.*(S|s)pot(ify)?.*)$"
        "workspace 4 silent, class:^(.*Obsidian.*)$"
        "workspace 4 silent, title:^(.*stellar-sanctum)$"
        "workspace 4 silent, class:^(org\.wezfurlong\.wezterm\.obsidian)$"
        "workspace 8 silent, class:^(org\.wezfurlong\.wezterm\.smos)$"
        "opacity 0.0 override, class:^(xwaylandvideobridge)$"
        "noanim, class:^(xwaylandvideobridge)$"
        "noinitialfocus, class:^(xwaylandvideobridge)$"
        "maxsize 1 1, class:^(xwaylandvideobridge)$"
        "noblur, class:^(xwaylandvideobridge)$"
        "idleinhibit fullscreen, class:^(helium|helium-browser)$"
        "idleinhibit focus, class:^(mpv|.+exe)$"
        "idleinhibit focus, title:^(.*Helium.*)$, title:^(.*YouTube.*)$"
      ];
    };
  };
  # }}}
  # {{{ Pyprland config
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
  # }}}
}
