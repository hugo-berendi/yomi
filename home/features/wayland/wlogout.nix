{
  config,
  lib,
  pkgs,
  ...
}: let
  shell = config.yomi.shellTheme;
  radius = toString config.yomi.theming.rounding.radius;
  entry = label: action: text: keybind: {
    inherit label action text keybind;
  };
  layout = [
    (entry "lock" "loginctl lock-session" "Lock" "l")
    (entry "logout" "hyprctl dispatch exit" "Log out" "e")
    (entry "suspend" "systemctl suspend" "Suspend" "s")
    (entry "hibernate" "systemctl hibernate" "Hibernate" "h")
    (entry "reboot" "systemctl reboot" "Reboot" "r")
    (entry "shutdown" "systemctl poweroff" "Shut down" "p")
  ];
  icon = name: "${pkgs.wlogout}/share/wlogout/icons/${name}.png";

  # wlogout stretches its buttons over whatever the margins leave free, so a
  # fixed flag set is right for one screen and wrong for the next. Size one
  # row of tiles from the focused monitor instead, and let a second press
  # close the menu rather than stack another on top.
  sessionMenu = pkgs.writeShellApplication {
    name = "yomi-session-menu";
    runtimeInputs = [pkgs.wlogout pkgs.jq pkgs.hyprland pkgs.procps];
    text = ''
      if pkill -x wlogout; then
        exit 0
      fi

      read -r width height < <(
        hyprctl monitors -j |
          jq -r '.[] | select(.focused) | "\(.width / .scale | floor) \(.height / .scale | floor)"'
      )

      buttons=${toString (builtins.length layout)}
      tile=$((height / 7))
      tile=$((tile > 200 ? 200 : tile < 120 ? 120 : tile))
      gap=$((tile / 8))
      row=$((buttons * tile + (buttons - 1) * gap))
      if ((row > width)); then
        buttons=3
        row=$((buttons * tile + (buttons - 1) * gap))
      fi
      rows=$(((${toString (builtins.length layout)} + buttons - 1) / buttons))
      tall=$((tile * 6 / 5))
      x=$(((width - row) / 2))
      y=$(((height - rows * tall - (rows - 1) * gap) / 2))

      exec wlogout --protocol layer-shell \
        --buttons-per-row "$buttons" --column-spacing "$gap" --row-spacing "$gap" \
        --margin-left "$x" --margin-right "$x" --margin-top "$y" --margin-bottom "$y" "$@"
    '';
  };
in {
  options.yomi.sessionMenu = lib.mkOption {
    type = lib.types.str;
    readOnly = true;
    description = "Command that toggles the session menu, for keybinds and bar buttons";
  };

  config = {
    yomi.sessionMenu = lib.getExe sessionMenu;

    home.packages = [pkgs.wlogout sessionMenu];

    xdg.configFile = {
      # wlogout reads a stream of bare objects, not an array: a JSON list makes
      # it exit 3 with "Invalid JSON Data" before drawing anything.
      "wlogout/layout".text = lib.concatMapStrings (e: builtins.toJSON e + "\n") layout;

      "wlogout/style.css".text = ''
        * {
          background-image: none;
          box-shadow: none;
          font-family: "${config.stylix.fonts.sansSerif.name}", "Symbols Nerd Font Mono";
          font-size: ${toString config.stylix.fonts.sizes.applications}pt;
        }

        window {
          background-color: ${shell.rgba "background" 0.62};
        }

        button {
          margin: 0;
          padding-bottom: 14px;
          border: 2px solid ${shell.rgba "overlay" 0.45};
          border-radius: ${radius}px;
          color: ${shell.palette.muted};
          background-color: ${shell.rgba "surface" 0.82};
          background-repeat: no-repeat;
          background-position: center 38%;
          background-size: 34%;
          transition: background-color 150ms ease, border-color 150ms ease, color 150ms ease;
        }

        button:focus,
        button:hover {
          outline-style: none;
          border-color: ${shell.palette.accent};
          color: ${shell.palette.textStrong};
          background-color: ${shell.rgba "surfaceRaised" 0.94};
          box-shadow: 0 0 0 4px ${shell.rgba "accent" 0.18};
        }

        /* The GTK theme colours the label node itself, so the button's
           color never reaches it and the focused tile read as disabled. */
        button label {
          color: ${shell.palette.muted};
        }

        button:focus label,
        button:hover label {
          color: ${shell.palette.textStrong};
          font-weight: 600;
        }

        button:active {
          background-color: ${shell.rgba "accent" 0.28};
        }

        #reboot:focus,
        #reboot:hover,
        #shutdown:focus,
        #shutdown:hover {
          border-color: ${shell.palette.critical};
          background-color: ${shell.rgba "critical" 0.16};
          box-shadow: 0 0 0 4px ${shell.rgba "critical" 0.18};
        }

        ${lib.concatMapStrings (e: ''
            #${e.label} {
              background-image: image(url("${icon e.label}"));
            }
          '')
          layout}
      '';
    };
  };
}
