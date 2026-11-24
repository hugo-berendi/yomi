# Hyprland's keybindings and the resize submap. Every bind carries a
# description: Hyprland reports it through `hyprctl binds -j`, which is what
# the SUPER+F1 sheet lists. The rest of the session is in ./default.nix.
{
  pkgs,
  lib,
  config,
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
  wayland.windowManager.hyprland.settings = {
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
    # }}}
  };

  wayland.windowManager.hyprland.submaps.resize.settings.bind = [
    (mkBindWith repeating "l" "Resize: wider" "hl.dsp.window.resize({ x = 10, y = 0, relative = true })")
    (mkBindWith repeating "h" "Resize: narrower" "hl.dsp.window.resize({ x = -10, y = 0, relative = true })")
    (mkBindWith repeating "k" "Resize: shorter" "hl.dsp.window.resize({ x = 0, y = -10, relative = true })")
    (mkBindWith repeating "j" "Resize: taller" "hl.dsp.window.resize({ x = 0, y = 10, relative = true })")
    (mkBind "escape" "Leave resize mode" ''hl.dsp.submap("reset")'')
  ];
}
