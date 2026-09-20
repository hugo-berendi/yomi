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
  sessionMenu = "${lib.getExe pkgs.wlogout} --protocol layer-shell --buttons-per-row 3";
  lua = lib.generators.mkLuaInline;
  luaString = builtins.toJSON;
  mkBind = keys: dispatcher: {
    _args = [keys (lua dispatcher)];
  };
  mkExecBind = keys: command: mkBind keys "hl.dsp.exec_cmd(${luaString command})";
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
    configType = "lua";

    package = pkgs.hyprland;
    portalPackage = null;

    systemd = {
      variables = ["--all"];
      enableXdgAutostart = true;
    };

    settings = {
      config = {
        decoration = {
          rounding = config.yomi.theming.rounding.radius;
          active_opacity = config.stylix.opacity.applications;
          inactive_opacity = lib.max 0.65 (config.stylix.opacity.applications - 0.08);

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
          resize_on_border = true;
        };

        cursor.inactive_timeout = 30;

        input = {
          kb_layout = "de";
          follow_mouse = 1;
          sensitivity = 0;

          touchpad = {
            disable_while_typing = true;
            natural_scroll = true;
            clickfinger_behavior = true;
            middle_button_emulation = false;
            tap_to_click = false;
          };
        };

        animations.enabled = true;
        dwindle.preserve_split = true;
        misc = {
          disable_hyprland_logo = true;
          disable_splash_rendering = true;
        };
      };

      animation = {
        leaf = "workspaces";
        enabled = true;
        speed = 4;
        bezier = "default";
        style = "slidevert";
      };

      # {{{ Monitors
      monitor =
        (lib.forEach config.yomi.monitors (
          m: {
            output = m.name;
            mode = "${toString m.width}x${toString m.height}@${toString m.refreshRate}";
            position = "${toString m.x}x${toString m.y}";
            scale = 1;
          }
        ))
        ++ [
          {
            output = "";
            mode = "preferred";
            position = "auto";
            scale = 1;
          }
        ];

      workspace_rule =
        lib.lists.concatMap (
          m:
            if m.workspace != null
            then let
              startWs = lib.toInt m.workspace;
            in
              lib.genList (i: {
                workspace = toString (startWs + i);
                monitor = m.name;
              })
              5
            else []
        )
        config.yomi.monitors;
      # }}}
      # {{{ Autostart
      on._args = [
        "hyprland.start"
        (lua ''
          function()
            hl.exec_cmd(${luaString config.yomi.terminal.execCommand})
            hl.exec_cmd("helium")
            hl.exec_cmd("vesktop")
            hl.exec_cmd(${luaString spotifyCmd})
            hl.exec_cmd("obsidiantui")
            hl.exec_cmd("pypr")
            hl.exec_cmd("command -v karere >/dev/null 2>&1 && karere || true")
            hl.exec_cmd("command -v teams-for-linux >/dev/null 2>&1 && teams-for-linux || true")
            hl.exec_cmd("systemctl --user start hyprpolkitagent")
          end
        '')
      ];
      # }}}

      env = [
        {
          _args = ["HYPRCURSOR_THEME" "rose-pine-hyprcursor"];
        }
        {
          _args = ["QT_QPA_PLATFORMTHEME" "qt6ct"];
        }
      ];

      # {{{ Keybindings
      bind =
        [
          (mkExecBind "SUPER + A" "pypr toggle volume")
          (mkExecBind "SUPER + SHIFT + RETURN" "pypr toggle term")
          (mkExecBind "SUPER + Y" "pypr attach")
          (mkExecBind "XF86AudioMute" "${swayosd} --output-volume mute-toggle")
          (mkExecBind "XF86AudioMicMute" "${swayosd} --input-volume mute-toggle")
          (mkExecBind "XF86AudioStop" "${lib.getExe pkgs.playerctl} stop")
          (mkExecBind "XF86AudioPrev" "${lib.getExe pkgs.playerctl} previous")
          (mkExecBind "XF86AudioNext" "${lib.getExe pkgs.playerctl} next")
          (mkExecBind "XF86AudioPlay" "${lib.getExe pkgs.playerctl} play-pause")
          (mkExecBind "SUPER + SPACE" "${vicinae} toggle")
          (mkExecBind "SUPER + V" "${vicinae} deeplink vicinae://launch/clipboard/history")
          (mkExecBind "SUPER + N" "${lib.getExe' config.services.swaync.package "swaync-client"} -t -sw")
          (mkExecBind "SUPER + T" "wl-ocr")
          (mkExecBind "SUPER + SHIFT + T" "wl-qr")
          (mkExecBind "SUPER + CONTROL + T" "hyprpicker | wl-copy && notify-send 'Copied color $(wp-paste)'")
          (mkExecBind "SUPER + B" "wlsunset-toggle")
          (mkExecBind "SUPER + RETURN" config.yomi.terminal.command)
          (mkExecBind "SUPER + PRINT" "grimblast --notify copysave area")
          (mkExecBind "SUPER + SHIFT + PRINT" "grimblast --notify copysave active")
          (mkExecBind "SUPER + CONTROL + PRINT" "grimblast --notify copysave screen")
          (mkExecBind "SUPER + ALT + PRINT" "wl-immich")
          (mkExecBind "SUPER + ESCAPE" sessionMenu)
          (mkBind "SUPER + F" "hl.dsp.window.fullscreen()")
          (mkBind "SUPER + Q" "hl.dsp.window.close()")
          (mkBind "SUPER + X" ''hl.dsp.workspace.toggle_special("")'')
          (mkBind "SUPER + SHIFT + X" ''hl.dsp.window.move({ workspace = "special" })'')
          (mkBind "SUPER + G" "hl.dsp.group.toggle()")
          (mkBind "SUPER + SHIFT + L" "hl.dsp.group.next()")
          (mkBind "SUPER + SHIFT + H" "hl.dsp.group.prev()")
          (mkBind "SUPER + H" ''hl.dsp.focus({ direction = "left" })'')
          (mkBind "SUPER + L" ''hl.dsp.focus({ direction = "right" })'')
          (mkBind "SUPER + K" ''hl.dsp.focus({ direction = "up" })'')
          (mkBind "SUPER + J" ''hl.dsp.focus({ direction = "down" })'')
          (mkBind "SUPER + R" ''hl.dsp.submap("resize")'')
        ]
        ++ (
          builtins.concatLists (
            builtins.genList (
              i: let
                ws = i + 1;
              in [
                (mkBind "SUPER + code:1${toString i}" "hl.dsp.focus({ workspace = ${luaString (toString ws)} })")
                (mkBind "SUPER + SHIFT + code:1${toString i}" "hl.dsp.window.move({ workspace = ${luaString (toString ws)} })")
              ]
            )
            10
          )
        )
        ++ (map (bind: bind // {_args = bind._args ++ [{repeating = true;}];}) [
          (mkExecBind "XF86AudioRaiseVolume" "${swayosd} --output-volume raise")
          (mkExecBind "XF86AudioLowerVolume" "${swayosd} --output-volume lower")
          (mkExecBind "XF86MonBrightnessDown" "${swayosd} --brightness lower")
          (mkExecBind "XF86MonBrightnessUp" "${swayosd} --brightness raise")
        ])
        ++ [
          {
            _args = ["SUPER + mouse:272" (lua "hl.dsp.window.drag()") {drag = true;}];
          }
          {
            _args = ["SUPER + mouse:273" (lua "hl.dsp.window.resize()") {drag = true;}];
          }
        ];

      window_rule = [
        {
          match.class = "^(com.mitchellh.ghostty)$";
          workspace = "1 silent";
        }
        {
          match.title = "^(.*Ghostty.*)$";
          workspace = "1 silent";
        }
        {
          match.class = "^(helium|helium-browser)$";
          workspace = "2 silent";
        }
        {
          match.title = "^(.*Helium.*)$";
          workspace = "2 silent";
        }
        {
          match.title = "^(.*((Disc|WebC|Venc)ord)|Vesktop.*)$";
          workspace = "3 silent";
        }
        {
          match.title = "^(.*Element.*)$";
          workspace = "3 silent";
        }
        {
          match.class = "^(teams-for-linux|teams|karere)$";
          workspace = "3 silent";
        }
        {
          match.title = "^(.*(Teams|Karere|WhatsApp).*)$";
          workspace = "3 silent";
        }
        {
          match.title = "^(.*(S|s)pot(ify)?.*)$";
          workspace = "5 silent";
        }
        {
          match.class = "^(.*Obsidian.*)$";
          workspace = "4 silent";
        }
        {
          match.title = "^(.*stellar-sanctum)$";
          workspace = "4 silent";
        }
        {
          match.class = "^(org\\.wezfurlong\\.wezterm\\.obsidian)$";
          workspace = "4 silent";
        }
        {
          match.class = "^(org\\.wezfurlong\\.wezterm\\.smos)$";
          workspace = "8 silent";
        }
        {
          match.class = "^(xwaylandvideobridge)$";
          opacity = "0.0 override";
          no_anim = true;
          no_initial_focus = true;
          max_size = "1 1";
          no_blur = true;
        }
        {
          match.class = "^(helium|helium-browser)$";
          idle_inhibit = "fullscreen";
        }
        {
          match.class = "^(mpv|.+exe)$";
          idle_inhibit = "focus";
        }
        {
          match.class = "^(helium|helium-browser)$";
          match.title = "^(.*YouTube.*)$";
          idle_inhibit = "focus";
        }
      ];

      layer_rule = [
        {
          match.namespace = "gtk-layer-shell";
          blur = true;
        }
        {
          match.namespace = "anyrun";
          blur = true;
          ignore_alpha = 0;
        }
        {
          match.namespace = "waybar";
          blur = true;
          ignore_alpha = 0;
        }
      ];
    };

    submaps.resize.settings.bind =
      (map (bind: bind // {_args = bind._args ++ [{repeating = true;}];}) [
        (mkBind "l" "hl.dsp.window.resize({ x = 10, y = 0, relative = true })")
        (mkBind "h" "hl.dsp.window.resize({ x = -10, y = 0, relative = true })")
        (mkBind "k" "hl.dsp.window.resize({ x = 0, y = -10, relative = true })")
        (mkBind "j" "hl.dsp.window.resize({ x = 0, y = 10, relative = true })")
      ])
      ++ [(mkBind "escape" ''hl.dsp.submap("reset")'')];
  };
  # }}}
  # {{{ Legacy config cleanup
  home.sessionVariables.HYPRLAND_CONFIG = "${config.xdg.configHome}/hypr/hyprland.lua";

  home.activation.removeLegacyHyprlandConfig = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
    legacyConfig="${config.xdg.configHome}/hypr/hyprland.conf"
    if [ -f "$legacyConfig" ] && [ ! -L "$legacyConfig" ] \
      && grep -qF "This config is a STUB!" "$legacyConfig" \
      && grep -qF "autogenerated = 1" "$legacyConfig"; then
      run rm -f "$legacyConfig"
    fi
  '';
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
