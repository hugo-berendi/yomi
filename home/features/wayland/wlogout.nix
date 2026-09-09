{
  config,
  lib,
  pkgs,
  ...
}: let
  shell = config.yomi.shellTheme;
  radius = toString config.yomi.theming.rounding.radius;
  wlogout = lib.getExe pkgs.wlogout;
  entry = label: action: text: keybind: {
    inherit label action text keybind;
  };
in {
  home.packages = [pkgs.wlogout];

  xdg.configFile = {
    "wlogout/layout".text = builtins.toJSON [
      (entry "lock" "loginctl lock-session" "Lock" "l")
      (entry "suspend" "systemctl suspend" "Suspend" "s")
      (entry "hibernate" "systemctl hibernate" "Hibernate" "h")
      (entry "logout" "hyprctl dispatch exit" "Logout" "e")
      (entry "reboot" "systemctl reboot" "Reboot" "r")
      (entry "shutdown" "systemctl poweroff" "Shut down" "p")
    ];

    "wlogout/style.css".text = ''
      * {
        background-image: none;
        font-family: "${config.stylix.fonts.sansSerif.name}", "Symbols Nerd Font Mono";
        font-size: ${toString config.stylix.fonts.sizes.applications}pt;
      }

      window {
        background: ${shell.rgba "background" 0.78};
      }

      button {
        margin: 18px;
        border: ${toString config.yomi.theming.rounding.size}px solid ${shell.rgba "accent" 0.48};
        border-radius: ${radius}px;
        color: ${shell.palette.textStrong};
        background-color: ${shell.rgba "surface" 0.9};
        background-repeat: no-repeat;
        background-position: center 42%;
        background-size: 22%;
        box-shadow: 0 10px 30px ${shell.rgba "background" 0.48};
        transition: background-color 180ms ease, border-color 180ms ease;
      }

      button:focus,
      button:active,
      button:hover {
        border-color: ${shell.palette.accent};
        color: ${shell.palette.bright};
        background-color: ${shell.rgba "surfaceRaised" 0.96};
        outline-style: none;
      }

      #lock {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/lock.png"));
      }

      #logout {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/logout.png"));
      }

      #suspend {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/suspend.png"));
      }

      #hibernate {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/hibernate.png"));
      }

      #shutdown {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/shutdown.png"));
      }

      #reboot {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/reboot.png"));
      }
    '';
  };

  home.sessionVariables.YOMI_SESSION_MENU = "${wlogout} --protocol layer-shell --buttons-per-row 3";
}
