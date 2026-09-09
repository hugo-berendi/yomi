{
  config,
  lib,
  ...
}: let
  shell = config.yomi.shellTheme;
  radius = toString config.yomi.theming.rounding.radius;
in {
  services.swaync = {
    enable = true;

    settings = {
      positionX = "right";
      positionY = "top";
      layer = "overlay";
      control-center-layer = "top";
      layer-shell = true;
      cssPriority = "user";
      control-center-width = 420;
      control-center-height = 720;
      control-center-margin-top = 56;
      control-center-margin-right = config.yomi.theming.gaps.outer;
      control-center-margin-bottom = config.yomi.theming.gaps.outer;
      control-center-margin-left = config.yomi.theming.gaps.outer;
      notification-window-width = 420;
      notification-icon-size = 48;
      notification-body-image-height = 120;
      notification-body-image-width = 220;
      notification-inline-replies = true;
      timeout = 6;
      timeout-low = 3;
      timeout-critical = 0;
      fit-to-screen = true;
      hide-on-clear = true;
      hide-on-action = true;
      widgets = [
        "title"
        "dnd"
        "notifications"
      ];
      widget-config = {
        title = {
          text = "Notifications";
          clear-all-button = true;
          button-text = "Clear";
        };
        dnd.text = "Do not disturb";
      };
    };

    style = ''
      * {
        font-family: "${config.stylix.fonts.sansSerif.name}", "Symbols Nerd Font Mono";
        font-size: ${toString config.stylix.fonts.sizes.applications}pt;
        color: ${shell.palette.text};
      }

      .control-center {
        padding: 12px;
        border: ${toString config.yomi.theming.rounding.size}px solid ${shell.rgba "accent" 0.56};
        border-radius: ${radius}px;
        background: ${shell.rgba "background" shell.opacity.elevated};
      }

      .control-center-list {
        background: transparent;
      }

      .notification-row {
        outline: none;
      }

      .notification-row:focus,
      .notification-row:hover {
        background: transparent;
      }

      .notification {
        margin: 6px;
        padding: 0;
        border: 1px solid ${shell.rgba "accent" 0.5};
        border-radius: ${radius}px;
        background: ${shell.rgba "surface" 0.96};
        box-shadow: 0 6px 20px ${shell.rgba "background" 0.42};
      }

      .notification-content {
        padding: 12px;
      }

      .summary {
        color: ${shell.palette.textStrong};
        font-weight: 700;
      }

      .body,
      .time {
        color: ${shell.palette.muted};
      }

      .critical {
        border-color: ${shell.palette.critical};
      }

      .close-button,
      .control-center-clear-all,
      .widget-dnd > switch {
        border-radius: ${radius}px;
        color: ${shell.palette.text};
        background: ${shell.rgba "surfaceRaised" 0.8};
      }

      .close-button:hover,
      .control-center-clear-all:hover {
        color: ${shell.palette.bright};
        background: ${shell.rgba "accent" 0.32};
      }

      .widget-title,
      .widget-dnd {
        margin: 6px;
        padding: 8px;
      }

      .widget-title > label {
        font-size: 1.15em;
        font-weight: 700;
      }

      .widget-dnd > switch:checked {
        background: ${shell.palette.accent};
      }

      .blank-window {
        background: transparent;
      }
    '';
  };
}
