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
  lua = lib.generators.mkLuaInline;
  luaString = builtins.toJSON;
  # Every bind carries a description; Hyprland reports it through
  # `hyprctl binds -j`, which is what the SUPER+F1 cheat sheet lists.
  # Focus the first window whose class contains `class` (plain substring,
  # case-insensitive), or start `command` when there is none -- Omarchy's
  # launch-or-focus, done inside Hyprland so it needs no hyprctl round trip.
  # SUPER+F1: every described bind, read back from the running compositor so
  # the list cannot drift from the config.
  # Internal panel of the Framework, if one is declared in yomi.monitors.
in {
  # {{{ Imports
  imports = [
    ../global.nix
    ./hyprpaper.nix
    ./hyprlock.nix
    ./hypridle.nix
    ./binds.nix
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
