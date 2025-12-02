{pkgs, ...}: {
  # {{{ Imports
  imports = [
    ./style.nix
  ];
  # }}}
  # {{{ Waybar
  programs.waybar = {
    enable = true;
    package = pkgs.waybar;
    systemd.enable = true;
    settings = {
      mainBar = {
        "position" = "top";
        "layer" = "top";
        "margin-top" = 20;
        "margin-left" = 20;
        "margin-right" = 20;
        "margin-bottom" = 0;
        "spacing" = 0;

        modules-left = [
          "hyprland/workspaces"
          "tray"
          "custom/music"
        ];

        modules-right = [
          "custom/dexcom"
          "custom/updates"
          "group/general"
          "group/hardware"
          "custom/power"
        ];

        "group/hardware" = {
          "orientation" = "horizontal";
          "modules" = [
            "disk"
            "cpu"
            "memory"
          ];
        };

        "group/general" = {
          "orientation" = "horizontal";
          "modules" = [
            "network"
            "bluetooth"
            "pulseaudio"
            "battery"
            "clock"
            "custom/weather"
          ];
        };

        "hyprland/workspaces" = {
          "active-only" = false;
          "disable-click" = false;
          "disable-scroll" = true;
          "all-outputs" = true;
          "format" = "{icon}";
          "format-icons" = {
            "default" = "";
            "urgent" = "";
            "active" = "";
          };
          "persistent-workspaces" = {
            "*" = 10;
          };
        };

        "tray" = {
          "icon-size" = 16;
          "spacing" = 4;
        };

        "custom/updates" = {
          "format" = "󰏗 {}";
          "tooltip-format" = "{}";
          "escape" = true;
          "return-type" = "json";
          "exec" = "${pkgs.writeShellScript "waybar-updates" ''
            if [ -e /run/current-system ]; then
              nix-store --query --requisites /run/current-system | wc -l | xargs -I {} echo '{"text": "{}" }'
            else
              echo '{"text": "N/A" }'
            fi
          ''}";
          "restart-interval" = 30;
          "tooltip" = false;
        };

        "custom/spotify" = {
          "format" = "<span foreground='#cba6f7'>󰎈 </span><span font='HackNerdFont weight=325 Italic'>{}</span>";
          "interval" = 1;
          "exec-if" = "pgrep spotify";
          "on-click" = "playerctl -p spotify play-pause";
          "on-scroll-up" = "playerctl -p spotify previous";
          "on-scroll-down" = "playerctl -p spotify next";
          "tooltip" = false;
          "escape" = true;
          "max-length" = 60;
          "exec" = "$HOME/.config/scripts/spotify.sh";
          "return-type" = "json";
        };

        "custom/music" = {
          "format" = "{icon}{}";
          "format-icons" = {
            "Paused" = " ";
            "Stopped" = " ";
          };
          "escape" = true;
          "tooltip" = true;
          "exec" = "~/.config/scripts/caway -b 15 -f 60";
          "return-type" = "json";
          "on-click" = "playerctl play-pause";
          "on-scroll-up" = "playerctl previous";
          "on-scroll-down" = "playerctl next";
          "on-click-right" = "g4music";
          "max-length" = 35;
        };

        "clock" = {
          "format" = "<span foreground='#C6AAE8'> </span>{:%a %d %H:%M}";
          "tooltip-format" = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        };

        "custom/weather" = {
          "exec" = "nix-shell ~/.config/scripts/shell.nix --run \"python ~/.config/scripts/weather.py\"";
          "restart-interval" = 300;
          "return-type" = "json";
          "on-click" = "xdg-open https://weather.com/en-IN/weather/today/l/$(location_id)";
        };

        "custom/dexcom" = {
          "exec" = "nix-shell ~/.config/scripts/shell.nix --run \"python ~/.config/scripts/dexcom.py\"";
          "restart-interval" = 300;
          "return-type" = "json";
          "format" = "{}";
        };

        "battery" = {
          "states" = {
            "warning" = 30;
            "critical" = 15;
          };
          "format" = "<span foreground='#B1E3AD'>{icon} </span>{capacity}% ";
          "format-warning" = "<span foreground='#B1E3AD'>{icon} </span>{capacity}% ";
          "format-critical" = "<span foreground='#E38C8F'>{icon} </span>{capacity}% ";
          "format-charging" = "<span foreground='#B1E3AD'>  </span>{capacity}% ";
          "format-plugged" = "<span foreground='#B1E3AD'>  </span>{capacity}% ";
          "format-alt" = "<span foreground='#B1E3AD'>{icon} </span>{time} ";
          "format-full" = "<span foreground='#B1E3AD'> </span> {capacity}% ";
          "format-icons" = [
            " "
            " "
            " "
            " "
            " "
          ];
          "tooltip-format" = "{time}";
        };

        "network" = {
          "format-wifi" = "<span foreground='#F2CECF'> </span> ";
          "format-ethernet" = "<span foreground='#F2CECF'>󰈀 </span> ";
          "format-linked" = "{ifname} (No IP)  ";
          "format-disconnected" = "<span foreground='#F2CECF'> </span> ";
          "tooltip-format-wifi" = "Signal Strength: {signalStrength}% ";
          "on-click" = "~/.config/scripts/toggle.sh wlan";
        };

        "bluetooth" = {
          "format" = "";
          "format-disabled" = "󰂲";
          "format-connected" = "󰂱";
          "tooltip-format" = "{controller_alias}\t{controller_address}";
          "tooltip-format-connected" = "{controller_alias}\t{controller_address}\n\n{device_enumerate}";
          "tooltip-format-enumerate-connected" = "{device_alias}\t{device_address}";
          "on-click" = "~/.config/scripts/toggle.sh bluetooth";
        };

        "pipewire" = {
          "on-click" = "pactl set-sink-mute @DEFAULT_SINK@ toggle";
          "format" = "<span foreground='#EBDDAA'>{icon}</span> {volume}% ";
          "format-muted" = "<span foreground='#EBDDAA'></span> Muted ";
          "format-icons" = {
            "headphone" = "";
            "hands-free" = "";
            "headset" = "";
            "phone" = "";
            "portable" = "";
            "car" = "";
            "default" = [
              ""
              ""
            ];
          };
        };

        "custom/power" = {
          "format" = "";
          "on-click" = "wlogout";
          "tooltip" = false;
        };

        "cpu" = {
          "format" = " {usage}% ";
          "on-click" = "kitty -e htop";
        };

        "memory" = {
          "format" = " {}% ";
          "on-click" = "kitty -e htop";
        };

        "disk" = {
          "interval" = 30;
          "format" = " {percentage_used}% ";
          "path" = "/";
          "on-click" = "kitty -e htop";
        };
      };
    };
  };
  # }}}
}
