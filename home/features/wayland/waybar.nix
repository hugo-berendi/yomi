{pkgs, ...}: {
  programs.waybar = {
    enable = true;
    package = pkgs.waybar;

    # settings = {
    #   mainBar = {
    #     position = "top";
    #     layer = "top";
    #     margin-left = 20;
    #     margin-right = 20;
    #     margin-top = 20;
    #     margin-bottom = 20;
    #     spacing = 0;

    #     modules-left = [
    #       "hyprland/workspaces"
    #       "custom/spotify"
    #     ];

    #     modules-right = [
    #       "custom/dexcom"
    #       "custom/updates"
    #       "group/general"
    #       "group/hardware"
    #       "custom/power"
    #     ];

    #     "group/hardware" = {
    #       "orientation" = "horizontal";
    #       "modules" = [
    #         "disk"
    #         "cpu"
    #         "memory"
    #       ];
    #     };

    #     "group/general" = {
    #       "orientation" = "horizontal";
    #       "modules" = [
    #         "network"
    #         "bluetooth"
    #         "pulseaudio"
    #         "battery"
    #         "clock"
    #         "custom/weather"
    #       ];
    #     };
    #   };
    #   "hyprland/workspaces" = {
    #     "on-click" = "activate";
    #     "active-only" = false;
    #     "disable-scroll" = true;
    #     "all-outputs" = true;
    #     "format" = "{icon}";
    #     "format-icons" = {
    #       "default" = "";
    #       "urgent" = "";
    #       "active" = "";
    #     };
    #     "persistent_workspaces" = {
    #       "*" = 10;
    #     };
    #   };

    #   "custom/updates" = {
    #     "format" = " {}";
    #     "tooltip-format" = "{}";
    #     "escape" = true;
    #     "return-type" = "json";
    #     "exec" = "~/.config/scripts/updates.sh";
    #     "restart-interval" = 30;
    #     "on-click" = "~/.config/scripts/installupdates.sh";
    #     "on-click-right" = "~/.config/.settings/software.sh";
    #     "tooltip" = false;
    #   };

    #   "custom/spotify" = {
    #     "format" = "<span foreground='#cba6f7'>󰎈 </span><span font='HackNerdFont weight=325 Italic'>{}</span>";
    #     "interval" = 1;
    #     "exec-if" = "pgrep spotify";
    #     "on-click" = "playerctl -p spotify play-pause";
    #     "on-scroll-up" = "playerctl -p spotify previous";
    #     "on-scroll-down" = "playerctl -p spotify next";
    #     "tooltip" = false;
    #     "escape" = true;
    #     "max-length" = 60;
    #     "exec" = "$HOME/bin/spotify.sh";
    #     "return-type" = "json";
    #   };

    #   "clock" = {
    #     "format" = "<span foreground='#C6AAE8'> </span>{ =%a %d %H =%M}";
    #     "tooltip-format" = "<big>{ =%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
    #   };

    #   "custom/weather" = {
    #     "exec" = "python ~/.config/scripts/weather.py";
    #     "restart-interval" = 300;
    #     "return-type" = "json";
    #     "on-click" = "xdg-open https =#weather.com/en-IN/weather/today/l/$(location_id)";
    #     # "format-alt" = "{alt}";
    #   };

    #   "custom/dexcom" = {
    #     "exec" = "python ~/.config/scripts/dexcom.py";
    #     "restart-interval" = 300;
    #     "return-type" = "json";
    #     "format" = "{}";
    #   };

    #   "battery" = {
    #     "states" = {
    #       "warning" = 30;
    #       "critical" = 15;
    #     };
    #     "format" = "<span foreground='#B1E3AD'>{icon} </span>{capacity}% ";
    #     "format-warning" = "<span foreground='#B1E3AD'>{icon} </span>{capacity}% ";
    #     "format-critical" = "<span foreground='#E38C8F'>{icon} </span>{capacity}% ";
    #     "format-charging" = "<span foreground='#B1E3AD'>  </span>{capacity}% ";
    #     "format-plugged" = "<span foreground='#B1E3AD'>  </span>{capacity}% ";
    #     "format-alt" = "<span foreground='#B1E3AD'>{icon} </span>{time} ";
    #     "format-full" = "<span foreground='#B1E3AD'> </span> {capacity}% ";
    #     "format-icons" = [" " " " " " " " " "];
    #     "tooltip-format" = "{time}";
    #   };

    #   "network" = {
    #     "format-wifi" = "<span foreground='#F2CECF'> </span> ";
    #     "format-ethernet" = "<span foreground='#F2CECF'>󰈀 </span> ";
    #     "format-linked" = "{ifname} (No IP)  ";
    #     "format-disconnected" = "<span foreground='#F2CECF'> </span> ";
    #     "tooltip-format-wifi" = "Signal Strenght = {signalStrength}% ";
    #     "on-click" = "~/.config/scripts/toggle.sh wlan";
    #   };

    #   "bluetooth" = {
    #     # "controller" = "controller1"; # specify the alias of the controller if there are more than 1 on the system
    #     "format" = "";
    #     "format-disabled" = "󰂲"; # an empty format will hide the module
    #     "format-connected" = "󰂱";
    #     "tooltip-format" = "{controller_alias}\t{controller_address}";
    #     "tooltip-format-connected" = "{controller_alias}\t{controller_address}\n\n{device_enumerate}";
    #     "tooltip-format-enumerate-connected" = "{device_alias}\t{device_address}";
    #     "on-click" = "~/.config/scripts/toggle.sh bluetooth";
    #   };

    #   "pipewire" = {
    #     "on-click" = "pactl set-sink-mute @DEFAULT_SINK@ toggle";
    #     "format" = "<span foreground='#EBDDAA'>{icon}</span> {volume}% ";
    #     "format-muted" = "<span foreground='#EBDDAA'></span> Muted ";
    #     "format-icons" = {
    #       "headphone" = "";
    #       "hands-free" = "";
    #       "headset" = "";
    #       "phone" = "";
    #       "portable" = "";
    #       "car" = "";
    #       "default" = ["" ""];
    #     };
    #   };

    #   "custom/power" = {
    #     "format" = "";
    #     "on-click" = "nwg-bar";
    #     "tooltip" = false;
    #   };

    #   cpu = {
    #     "format" = " {usage}% ";
    #     "on-click" = "kitty -e htop";
    #   };

    #   memory = {
    #     "format" = "<span font_desc='Font Awesome 6 Free'> </span>{}% ";
    #     "on-click" = "kitty -e htop";
    #   };

    #   disk = {
    #     "interval" = 30;
    #     "format" = " {percentage_used}% ";
    #     "path" = "/home/";
    #     "on-click" = "kitty -e htop";
    #   };
    # };

    # style = ''
    #   @define-color base            #232136;
    #   @define-color surface         #2a273f;
    #   @define-color overlay         #393552;

    #   @define-color muted           #6e6a86;
    #   @define-color subtle          #908caa;
    #   @define-color text            #e0def4;

    #   @define-color love            #eb6f92;
    #   @define-color gold            #f6c177;
    #   @define-color rose            #ea9a97;
    #   @define-color pine            #3e8fb0;
    #   @define-color foam            #9ccfd8;
    #   @define-color iris            #c4a7e7;

    #   @define-color highlightLow    #2a283e;
    #   @define-color highlightMed    #44415a;
    #   @define-color highlightHigh   #56526e;

    #   @define-color cmantle rgba(10, 15, 15, 0.85);

    #   * {
    #     border-radius: 0;
    #     font-family: "Maple Mono NF", "Font Awesome 6 Free", Roboto, Helvetica, Arial,
    #       sans-serif;
    #     font-size: 22px;
    #     min-height: 0;
    #     border-radius: 35px;
    #   }

    #   window#waybar {
    #     background: transparent;
    #     color: @text;
    #   }

    #   #workspaces {
    #     margin-right: 5px;
    #     margin-top: 5px;
    #     margin-bottom: 5px;
    #     padding: 8px;
    #     font-weight: normal;
    #     font-style: normal;
    #     transition: all 0.3s ease-in-out;
    #   }

    #   #workspaces button {
    #     padding: 0px;
    #     margin: 0 3px;
    #     min-width: 30px;
    #     color: @love;
    #     background: @love;
    #     transition: all 0.3s ease-in-out;
    #     opacity: 0.4;
    #     font-size: 10;
    #   }

    #   #workspaces button.active {
    #     color: @love;
    #     background: @love;
    #     min-width: 50px;
    #     background-size: 400% 400%;
    #     opacity: 1;
    #   }

    #   #workspaces button:hover {
    #     background: @love;
    #     color: @love;
    #     min-width: 50px;
    #     background-size: 400% 400%;
    #   }

    #   /*
    #   #workspaces {
    #       margin-left: 5px;
    #       margin-right: 5px;
    #       margin-top: 5px;
    #       margin-bottom: 5px;
    #       padding: 2px 20px 2px 15px;
    #   }

    #   #workspaces button {
    #       padding-left: 10px;
    #       padding-right: 10px;
    #       margin: 0;
    #       min-width: 0;
    #       color: @text;
    #   }

    #   #workspaces button.active {
    #       color: @mauve;
    #   }

    #   #workspaces button.urgent {
    #       color: #F9C096;
    #   }

    #   #workspaces button:hover {
    #   	color: @mauve;
    #   }
    #   */

    #   #custom-spotify,
    #   #custom-updates,
    #   #workspaces,
    #   #disk,
    #   #cpu,
    #   #memory,
    #   #network,
    #   #pulseaudio,
    #   #battery,
    #   #clock,
    #   #custom-power,
    #   #bluetooth,
    #   #custom-weather,
    #   tooltip,
    #   #custom-dexcom {
    #     background:
    #       linear-gradient(@cmantle, @cmantle) padding-box,
    #       linear-gradient(@love, @love) border-box;
    #     border-width: 3px;
    #     border-style: solid;
    #     border-color: transparent;
    #     margin-top: 5px;
    #     margin-bottom: 5px;
    #     padding-top: 5px;
    #     padding-bottom: 5px;
    #   }

    #   tooltip {
    #     padding: 20px;
    #     margin-top: 30px;
    #   }

    #   /* left of a group */
    #   #network,
    #   #disk {
    #     border-right-style: none;
    #     border-radius: 35px 0 0 35px;
    #     margin-left: 5px;
    #     padding-left: 15px;
    #     padding-right: 3px;
    #   }

    #   /* middle of a group */
    #   #pulseaudio,
    #   #battery,
    #   #cpu,
    #   #bluetooth,
    #   #clock {
    #     border-right-style: none;
    #     border-left-style: none;
    #     border-radius: 0 0 0 0;
    #     padding-right: 2px;
    #     padding-left: 2px;
    #   }

    #   /* right of a group */
    #   #custom-weather,
    #   #memory {
    #     border-left-style: none;
    #     border-radius: 0 35px 35px 0;
    #     margin-right: 5px;
    #     padding-right: 15px;
    #     padding-left: 3px;
    #   }

    #   #custom-updates {
    #     margin-top: 5px;
    #     margin-bottom: 5px;
    #     margin-right: 5px;
    #     margin-left: 5px;
    #     padding-right: 15px;
    #     padding-left: 15px;
    #   }

    #   #bluetooth {
    #     padding-right: 15px;
    #     color: @pine;
    #   }

    #   #pulseaudio {
    #     padding-right: 8px;
    #   }

    #   #network {
    #     padding-left: 15px;
    #     padding-right: 0px;
    #     margin-top: 5px;
    #     margin-bottom: 5px;
    #   }

    #   #custom-spotify {
    #     margin-top: 5px;
    #     margin-bottom: 5px;
    #     margin-left: 5px;
    #     padding-right: 15px;
    #     padding-left: 15px;
    #   }

    #   #custom-power {
    #     margin-top: 5px;
    #     margin-bottom: 5px;
    #     margin-left: 5px;
    #     padding-right: 16px;
    #     padding-left: 10px;
    #   }

    #   #custom-weather .severe {
    #     color: #eb937d;
    #   }

    #   #custom-weather .sunnyDay {
    #     color: #c2ca76;
    #   }

    #   #custom-weather .clearNight {
    #     color: #2b2b2a;
    #   }

    #   #custom-weather .cloudyFoggyDay,
    #   #custom-weather .cloudyFoggyNight {
    #     color: #c2ddda;
    #   }

    #   #custom-weather .rainyDay,
    #   #custom-weather .rainyNight {
    #     color: #5aaca5;
    #   }

    #   #custom-weather .showyIcyDay,
    #   #custom-weather .snowyIcyNight {
    #     color: #d6e7e5;
    #   }

    #   #custom-weather .default {
    #     color: #dbd9d8;
    #   }

    #   #custom-weather {
    #     padding-left: 10px;
    #   }

    #   #custom-dexcom .doubleup,
    #   #custom-dexcom .doubledown {
    #     color: @love;
    #   }

    #   #custom-dexcom .up,
    #   #custom-dexcom .down {
    #     color: @rose;
    #   }

    #   #custom-dexcom .right {
    #     color: @foam;
    #   }

    #   #custom-dexcom {
    #     padding-right: 15px;
    #     padding-left: 10px;
    #     margin-right: 5px;
    #   }
    # '';

    # systemd.enable = true;
    # systemd.target = "hyprland-session.target";
  };

  stylix.targets.waybar = {enable = false;};
}
