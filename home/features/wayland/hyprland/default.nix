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
    cliphist
    inputs.pyprland.packages."x86_64-linux".pyprland
  ];

  stylix.targets.hyprland.enable = false;
  wayland.windowManager.hyprland = {
    enable = true;
    package = pkgs.hyprland;
    extraConfig = builtins.readFile ./hyprland.conf;

    systemd.variables = ["--all"];

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
          xray = true;
          size = config.yomi.theming.blur.size;
          passes = config.yomi.theming.blur.passes;
          contrast = config.yomi.theming.blur.contrast;
          brightness = config.yomi.theming.blur.brightness;
          noise = 5.0e-2;
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
        "kitty & firefox & vesktop & spotify & obsidiantui & pypr & xwaylandvideobridge"
        "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
        # "wl-paste --type text --watch cliphist store" # Stores only text data
        # "wl-paste --type image --watch cliphist store" # Stores only image data
      ];
      # }}}

      # {{{ Keybindings
      "$mod" = "SUPER";
      bind = [
        "$mod, C, exec, cliphist list | anyrun --plugins ${inputs.anyrun.packages.${pkgs.system}.stdin}/lib/libstdin.so | cliphist decode | wl-copy"
        "$mod, V, exec, pypr toggle volume"
        "$mod Shift, Return, exec, pypr toggle term"
        "$mod, Y, exec, pypr attach"
      ];
      # }}}
    };
  };

  services.cliphist = {
    enable = true;
    allowImages = true;
    systemdTarget = "graphical-session.target";
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
