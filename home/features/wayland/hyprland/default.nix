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
  ];

  stylix.targets.hyprland.enable = true;
  wayland.windowManager.hyprland = {
    enable = true;
    package = pkgs.hyprland;
    extraConfig = builtins.readFile ./hyprland.conf;

    plugins = [
      # {{{ Plugins
      # inputs.hy3.packages.x86_64-linux.hy3
      # }}}
    ];

    settings = {
      # {{{ Decoration
      #decoration = {
      #  rounding = config.satellite.theming.rounding.radius;
      #  active_opacity = 1;
      #  inactive_opacity = 1;

      #  blur = {
      #    enabled = config.satellite.theming.blur.enable;
      #    ignore_opacity = true;
      #    xray = true;
      #    size = config.satellite.theming.blur.size;
      #    passes = config.satellite.theming.blur.passes;
      #    contrast = config.satellite.theming.blur.contrast;
      #    brightness = config.satellite.theming.blur.brightness;
      #    noise = 0.05;
      #  };
      #};
      # }}}

      # {{{ Monitors
      # Configure monitor properties
      monitor = lib.forEach config.satellite.monitors (
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
        lib.lists.concatMap
        (m: lib.lists.optional (m.workspace != null) "${m.name},${m.workspace}")
        config.satellite.monitors;
      # }}}

      # {{{ Keybindings
      "$mod" = "SUPER";
      bind = [
        "$mod, C, exec, cliphist list | anyrun --plugins ${inputs.anyrun.packages.${pkgs.system}.stdin}/lib/libstdin.so | cliphist decode | wl-copy"
      ];
    };
  };
}
