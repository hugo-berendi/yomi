{config, ...}: let
  shell = config.yomi.shellTheme;
  radius = toString config.yomi.theming.rounding.radius;
in {
  programs.waybar.style = ''
    * {
      min-height: 0;
      border: none;
      border-radius: 0;
      font-family: "${config.stylix.fonts.sansSerif.name}", "Symbols Nerd Font Mono";
      font-size: ${toString config.stylix.fonts.sizes.desktop}pt;
    }

    window#waybar {
      color: ${shell.palette.text};
      background: transparent;
    }

    .modules-left,
    .modules-center,
    .modules-right {
      padding: 4px;
      border: ${toString config.yomi.theming.rounding.size}px solid ${shell.rgba "accent" 0.52};
      border-radius: ${radius}px;
      background: ${shell.rgba "background" shell.opacity.panel};
      box-shadow: 0 4px 16px ${shell.rgba "background" 0.35};
    }

    #custom-launcher,
    #workspaces,
    #window,
    #clock,
    #mpris,
    #tray,
    #network,
    #bluetooth,
    #pulseaudio,
    #cpu,
    #memory,
    #battery,
    #custom-notifications,
    #custom-power {
      margin: 0 2px;
      padding: 0 10px;
      border-radius: ${radius}px;
      transition: background-color 160ms ease, color 160ms ease;
    }

    #custom-launcher,
    #custom-notifications,
    #custom-power {
      color: ${shell.palette.accent};
      font-size: 15px;
    }

    #workspaces {
      padding: 0 4px;
    }

    #workspaces button {
      min-width: 18px;
      padding: 0 3px;
      color: ${shell.palette.muted};
      background: transparent;
      box-shadow: none;
      transition: color 160ms ease, min-width 160ms ease;
    }

    #workspaces button.active {
      min-width: 26px;
      color: ${shell.palette.accent};
    }

    #workspaces button.urgent {
      color: ${shell.palette.critical};
    }

    #window {
      color: ${shell.palette.muted};
    }

    #clock {
      color: ${shell.palette.textStrong};
      font-weight: 700;
    }

    #mpris {
      color: ${shell.palette.secondary};
    }

    #network,
    #bluetooth,
    #pulseaudio {
      color: ${shell.palette.info};
    }

    #battery.warning {
      color: ${shell.palette.attention};
    }

    #battery.critical {
      color: ${shell.palette.critical};
    }

    #custom-launcher:hover,
    #workspaces button:hover,
    #clock:hover,
    #mpris:hover,
    #network:hover,
    #bluetooth:hover,
    #pulseaudio:hover,
    #custom-notifications:hover,
    #custom-power:hover {
      color: ${shell.palette.bright};
      background: ${shell.rgba "surfaceRaised" 0.72};
    }

    tooltip {
      color: ${shell.palette.text};
      background: ${shell.rgba "background" shell.opacity.elevated};
      border: ${toString config.yomi.theming.rounding.size}px solid ${shell.palette.accent};
      border-radius: ${radius}px;
    }

    tooltip label {
      padding: 8px;
    }
  '';
}
