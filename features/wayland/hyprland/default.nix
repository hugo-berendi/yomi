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
  sessionMenu = config.yomi.sessionMenu;
  swaync = lib.getExe' config.services.swaync.package "swaync-client";
  lua = lib.generators.mkLuaInline;
  luaString = builtins.toJSON;
  # Every bind carries a description; Hyprland reports it through
  # `hyprctl binds -j`, which is what the SUPER+F1 cheat sheet lists.
  mkBindWith = opts: keys: description: dispatcher: {
    _args = [keys (lua dispatcher) ({inherit description;} // opts)];
  };
  mkBind = mkBindWith {};
  mkExecBindWith = opts: keys: description: command:
    mkBindWith opts keys description "hl.dsp.exec_cmd(${luaString command})";
  mkExecBind = mkExecBindWith {};
  repeating = {repeating = true;};

  # Focus the first window whose class contains `class` (plain substring,
  # case-insensitive), or start `command` when there is none -- Omarchy's
  # launch-or-focus, done inside Hyprland so it needs no hyprctl round trip.
  launchOrFocus = class: command: ''
    function()
      for _, w in ipairs(hl.get_windows()) do
        if w.class and w.class:lower():find(${luaString (lib.toLower class)}, 1, true) then
          hl.dispatch(hl.dsp.focus({ window = w }))
          return
        end
      end
      hl.dispatch(hl.dsp.exec_cmd(${luaString command}))
    end
  '';

  pypr = "pypr";
  hyprctl = lib.getExe' config.wayland.windowManager.hyprland.package "hyprctl";

  # SUPER+F1: every described bind, read back from the running compositor so
  # the list cannot drift from the config.
  keybindSheet = pkgs.writeShellApplication {
    name = "hypr-keybinds";
    runtimeInputs = [pkgs.jq];
    text = ''
      ${hyprctl} binds -j | jq -r '
        .[]
        | select(.has_description)
        | . as $b
        | ([ [64, "SUPER"], [4, "CTRL"], [8, "ALT"], [1, "SHIFT"] ]
            | map(select((($b.modmask / .[0]) | floor) % 2 == 1) | .[1])) as $m
        | (if .key != "" then .key
           elif .keycode >= 10 and .keycode <= 19 then ((.keycode - 9) % 10 | tostring)
           else "code:\(.keycode)" end) as $k
        | "\(($m + [$k]) | join(" + "))  ·  \(.description)"
      ' | ${lib.getExe config.programs.vicinae.package} dmenu \
            --navigation-title "Keybindings" --placeholder "Search keybindings" >/dev/null || true
    '';
  };

  # Internal panel of the Framework, if one is declared in yomi.monitors.
  internalMonitor = lib.findFirst (m: m.name == "eDP-1") null config.yomi.monitors;
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
    wiremix # audio panel
    bluetui # bluetooth panel
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
          # {{{ Launchers and menus
          (mkExecBind "SUPER + SPACE" "Launcher" "${vicinae} toggle")
          (mkExecBind "SUPER + V" "Clipboard history" "${vicinae} deeplink vicinae://launch/clipboard/history")
          (mkExecBind "SUPER + F1" "Show keybindings" (lib.getExe keybindSheet))
          (mkExecBind "SUPER + ESCAPE" "Session menu" sessionMenu)
          (mkExecBind "SUPER + RETURN" "Terminal" config.yomi.terminal.command)
          (mkExecBind "SUPER + E" "File manager" "nautilus --new-window")
          (mkBind "SUPER + W" "Browser (focus or start)" (launchOrFocus "helium" "helium"))
          (mkBind "SUPER + M" "Music (focus or start)" (launchOrFocus "spotify" spotifyCmd))
          (mkBind "SUPER + D" "Discord (focus or start)" (launchOrFocus "vesktop" "vesktop"))
          (mkExecBind "XF86Calculator" "Calculator" "gnome-calculator")
          # }}}
          # {{{ Scratchpads and control panels
          (mkExecBind "SUPER + A" "Volume mixer" "${pypr} toggle volume")
          (mkExecBind "SUPER + SHIFT + RETURN" "Drop-down terminal" "${pypr} toggle term")
          (mkExecBind "SUPER + Y" "Attach window to scratchpad" "${pypr} attach")
          (mkExecBind "SUPER + CONTROL + A" "Audio panel (wiremix)" "${pypr} toggle audio")
          (mkExecBind "SUPER + CONTROL + B" "Bluetooth panel (bluetui)" "${pypr} toggle bluetooth")
          (mkExecBind "SUPER + CONTROL + W" "Wi-Fi panel (nmtui)" "${pypr} toggle wifi")
          (mkExecBind "SUPER + CONTROL + M" "Activity monitor (nixtop)" "${pypr} toggle activity")
          (mkExecBind "SUPER + N" "Notification center" "${swaync} -t -sw")
          # }}}
          # {{{ Toggles
          (mkExecBind "SUPER + B" "Toggle night light" "wlsunset-toggle")
          (mkExecBind "SUPER + CONTROL + I" "Toggle idle lock" "idle-toggle")
          (mkExecBind "SUPER + CONTROL + N" "Toggle do not disturb" "${swaync} -d -sw")
          # }}}
          # {{{ Capture
          (mkExecBind "SUPER + T" "OCR area to clipboard" "wl-ocr")
          (mkExecBind "SUPER + SHIFT + T" "Scan QR code in area" "wl-qr")
          (mkExecBind "SUPER + CONTROL + T" "Pick colour to clipboard" "hyprpicker | wl-copy && notify-send \"Copied colour $(wl-paste)\"")
          (mkExecBind "PRINT" "Screenshot area" "grimblast --freeze --notify copysave area")
          (mkExecBind "SUPER + PRINT" "Screenshot area and annotate" "grimblast --freeze save area - | satty --filename - --copy-command wl-copy")
          (mkExecBind "SUPER + SHIFT + PRINT" "Screenshot window" "grimblast --notify copysave active")
          (mkExecBind "SUPER + CONTROL + PRINT" "Screenshot screen" "grimblast --notify copysave screen")
          (mkExecBind "SUPER + ALT + PRINT" "Screenshot to Immich share link" "wl-immich")
          (mkExecBind "ALT + PRINT" "Start/stop screen recording of area" "screenrecord-toggle")
          # }}}
          # {{{ Media
          (mkExecBind "XF86AudioMute" "Mute output" "${swayosd} --output-volume mute-toggle")
          (mkExecBind "XF86AudioMicMute" "Mute microphone" "${swayosd} --input-volume mute-toggle")
          (mkExecBind "XF86AudioStop" "Stop playback" "${lib.getExe pkgs.playerctl} stop")
          (mkExecBind "XF86AudioPrev" "Previous track" "${lib.getExe pkgs.playerctl} previous")
          (mkExecBind "XF86AudioNext" "Next track" "${lib.getExe pkgs.playerctl} next")
          (mkExecBind "XF86AudioPlay" "Play/pause" "${lib.getExe pkgs.playerctl} play-pause")
          (mkExecBindWith repeating "XF86AudioRaiseVolume" "Volume up" "${swayosd} --output-volume raise")
          (mkExecBindWith repeating "XF86AudioLowerVolume" "Volume down" "${swayosd} --output-volume lower")
          (mkExecBindWith repeating "XF86MonBrightnessDown" "Brightness down" "${swayosd} --brightness lower")
          (mkExecBindWith repeating "XF86MonBrightnessUp" "Brightness up" "${swayosd} --brightness raise")
          # }}}
          # {{{ Windows
          (mkBind "SUPER + F" "Fullscreen" "hl.dsp.window.fullscreen()")
          (mkBind "SUPER + Q" "Close window" "hl.dsp.window.close()")
          (mkBind "SUPER + X" "Toggle special workspace" ''hl.dsp.workspace.toggle_special("")'')
          (mkBind "SUPER + SHIFT + X" "Move window to special workspace" ''hl.dsp.window.move({ workspace = "special" })'')
          (mkBind "SUPER + G" "Toggle group" "hl.dsp.group.toggle()")
          (mkBind "SUPER + SHIFT + L" "Next window in group" "hl.dsp.group.next()")
          (mkBind "SUPER + SHIFT + H" "Previous window in group" "hl.dsp.group.prev()")
          (mkBind "SUPER + H" "Focus left" ''hl.dsp.focus({ direction = "left" })'')
          (mkBind "SUPER + L" "Focus right" ''hl.dsp.focus({ direction = "right" })'')
          (mkBind "SUPER + K" "Focus up" ''hl.dsp.focus({ direction = "up" })'')
          (mkBind "SUPER + J" "Focus down" ''hl.dsp.focus({ direction = "down" })'')
          (mkBind "SUPER + R" "Resize mode (hjkl, Esc to leave)" ''hl.dsp.submap("resize")'')
          # }}}
        ]
        ++ (
          builtins.concatLists (
            builtins.genList (
              i: let
                ws = toString (i + 1);
              in [
                (mkBind "SUPER + code:1${toString i}" "Workspace ${ws}" "hl.dsp.focus({ workspace = ${luaString ws} })")
                (mkBind "SUPER + SHIFT + code:1${toString i}" "Move window to workspace ${ws}" "hl.dsp.window.move({ workspace = ${luaString ws} })")
              ]
            )
            10
          )
        )
        ++ lib.optionals (internalMonitor != null) [
          # {{{ Lid
          # Closing the lid with an external screen attached keeps the session
          # running (HandleLidSwitchDocked = ignore) but left the internal panel
          # on behind the lid, holding workspaces. Switch it off while the lid
          # is closed and something else is connected; opening the lid brings
          # it back with its usual mode and position. `locked` keeps this
          # working on the lock screen.
          (mkBindWith {locked = true;} "switch:on:Lid Switch" "Lid closed: turn off the internal panel when docked" ''
            function()
              if #hl.get_monitors() > 1 then
                hl.monitor({ output = ${luaString internalMonitor.name}, disabled = true })
              end
            end
          '')
          (mkBindWith {locked = true;} "switch:off:Lid Switch" "Lid opened: turn the internal panel back on" ''
            function()
              hl.monitor({ output = ${luaString internalMonitor.name}, disabled = false })
            end
          '')
          # }}}
        ]
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
          match.namespace = "logout_dialog";
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

    submaps.resize.settings.bind = [
      (mkBindWith repeating "l" "Resize: wider" "hl.dsp.window.resize({ x = 10, y = 0, relative = true })")
      (mkBindWith repeating "h" "Resize: narrower" "hl.dsp.window.resize({ x = -10, y = 0, relative = true })")
      (mkBindWith repeating "k" "Resize: shorter" "hl.dsp.window.resize({ x = 0, y = -10, relative = true })")
      (mkBindWith repeating "j" "Resize: taller" "hl.dsp.window.resize({ x = 0, y = 10, relative = true })")
      (mkBind "escape" "Leave resize mode" ''hl.dsp.submap("reset")'')
    ];
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
  xdg.configFile."hypr/pyprland.toml".text =
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

      # nixtop panels, toggled by clicking their Waybar modules.
      [scratchpads.nixtop-nix]
        animation = "fromTop"
        command = "foot -a nixtop-nix nixtop --panel nix"
        class = "nixtop-nix"
        size = "45% 30%"
        unfocus = "hide"
        lazy = true

      [scratchpads.nixtop-cpu]
        animation = "fromTop"
        command = "foot -a nixtop-cpu nixtop --panel cpu"
        class = "nixtop-cpu"
        size = "50% 35%"
        unfocus = "hide"
        lazy = true

      [scratchpads.nixtop-memory]
        animation = "fromTop"
        command = "foot -a nixtop-memory nixtop --panel memory"
        class = "nixtop-memory"
        size = "40% 30%"
        unfocus = "hide"
        lazy = true

      # Control panels (Omarchy's TUI panels), toggled with SUPER+CTRL+A/B/W/M
      # or by clicking the matching Waybar module.
      [scratchpads.audio]
        animation = "fromTop"
        command = "foot -a yomi-audio wiremix"
        class = "yomi-audio"
        size = "45% 50%"
        unfocus = "hide"
        lazy = true

      [scratchpads.bluetooth]
        animation = "fromTop"
        command = "foot -a yomi-bluetooth bluetui"
        class = "yomi-bluetooth"
        size = "45% 50%"
        unfocus = "hide"
        lazy = true

      [scratchpads.wifi]
        animation = "fromTop"
        command = "foot -a yomi-wifi nmtui"
        class = "yomi-wifi"
        size = "45% 55%"
        unfocus = "hide"
        lazy = true

      [scratchpads.activity]
        animation = "fromTop"
        command = "foot -a yomi-activity nixtop"
        class = "yomi-activity"
        size = "75% 70%"
        unfocus = "hide"
        lazy = true
    '';
  # }}}
}
