{
  config,
  lib,
  pkgs,
  ...
}: let
  vicinae = lib.getExe config.programs.vicinae.package;
in {
  imports = [./style.nix];

  programs.waybar = {
    enable = true;
    package = pkgs.waybar;
    systemd = {
      enable = true;
      targets = ["graphical-session.target"];
    };

    settings.mainBar = {
      position = "top";
      layer = "top";
      height = 42;
      margin-top = config.yomi.theming.gaps.inner;
      margin-left = config.yomi.theming.gaps.outer;
      margin-right = config.yomi.theming.gaps.outer;
      spacing = 6;
      fixed-center = true;

      modules-left = [
        "custom/launcher"
        "hyprland/workspaces"
        "hyprland/window"
      ];

      modules-center = ["clock"];

      modules-right = [
        "mpris"
        "tray"
        "network"
        "bluetooth"
        "pulseaudio"
        "cpu"
        "memory"
        "battery"
        "custom/notifications"
        "custom/power"
      ];

      "custom/launcher" = {
        format = "󰀻";
        tooltip = false;
        on-click = "${vicinae} toggle";
      };

      "hyprland/workspaces" = {
        format = "{icon}";
        format-icons = {
          active = "";
          default = "";
          urgent = "";
        };
        persistent-workspaces."*" = 10;
        disable-scroll = true;
        sort-by-number = true;
      };

      "hyprland/window" = {
        format = "{title}";
        icon = true;
        icon-size = 16;
        max-length = 48;
        separate-outputs = true;
        rewrite = {
          "(.*) — Mozilla Firefox" = "$1";
          "(.*) - Visual Studio Code" = "$1";
        };
      };

      clock = {
        format = "{:%H:%M}";
        format-alt = "{:%A, %d %B  •  %H:%M}";
        tooltip-format = "<big>{:%B %Y}</big>\n<tt>{calendar}</tt>";
        calendar = {
          mode = "month";
          weeks-pos = "right";
          on-scroll = 1;
          format = {
            months = "<b>{}</b>";
            days = "{}";
            weeks = "<span color='#${config.lib.stylix.colors.base0D}'>W{}</span>";
            weekdays = "<b>{}</b>";
            today = "<b><u>{}</u></b>";
          };
        };
      };

      mpris = {
        format = "{player_icon}  {dynamic}";
        format-paused = "{status_icon}  {dynamic}";
        player-icons.default = "󰎈";
        status-icons.paused = "";
        dynamic-order = [
          "title"
          "artist"
        ];
        dynamic-len = 32;
        tooltip-format = "{player}: {artist} — {title}";
        on-click = "${lib.getExe pkgs.playerctl} play-pause";
        on-click-right = "${lib.getExe pkgs.playerctl} next";
      };

      tray = {
        icon-size = 16;
        spacing = 8;
      };

      network = {
        interval = 3;
        format-wifi = "  {signalStrength}%";
        format-ethernet = "󰈀";
        format-linked = "󰈀  no IP";
        format-disconnected = "󰤮";
        tooltip-format-wifi = "{essid}\n{ipaddr}\n{bandwidthDownBytes} ↓  {bandwidthUpBytes} ↑";
        tooltip-format-ethernet = "{ifname}\n{ipaddr}";
        on-click = "${lib.getExe' pkgs.networkmanagerapplet "nm-connection-editor"}";
      };

      bluetooth = {
        format = "";
        format-disabled = "󰂲";
        format-connected = "󰂱 {num_connections}";
        tooltip-format = "{controller_alias}";
        tooltip-format-connected = "{device_enumerate}";
        tooltip-format-enumerate-connected = "{device_alias}";
        on-click = "${lib.getExe pkgs.overskride}";
      };

      pulseaudio = {
        format = "{icon}  {volume}%";
        format-bluetooth = " {volume}%";
        format-muted = "󰖁";
        format-icons.default = [
          ""
          ""
          ""
        ];
        on-click = "${lib.getExe pkgs.pwvucontrol}";
        on-click-right = "${lib.getExe' pkgs.pulseaudio "pactl"} set-sink-mute @DEFAULT_SINK@ toggle";
      };

      cpu = {
        interval = 5;
        format = "  {usage}%";
        tooltip = false;
      };

      memory = {
        interval = 5;
        format = "  {percentage}%";
        tooltip-format = "{used:0.1f} GiB of {total:0.1f} GiB";
      };

      battery = {
        interval = 10;
        states = {
          warning = 30;
          critical = 15;
        };
        format = "{icon}  {capacity}%";
        format-charging = "󰂄  {capacity}%";
        format-plugged = "  {capacity}%";
        format-icons = [
          "󰁺"
          "󰁻"
          "󰁼"
          "󰁽"
          "󰁾"
          "󰁿"
          "󰂀"
          "󰂁"
          "󰂂"
          "󰁹"
        ];
        tooltip-format = "{timeTo}";
      };

      "custom/notifications" = {
        exec = "${lib.getExe' config.services.swaync.package "swaync-client"} -swb";
        return-type = "json";
        format = "{icon}";
        format-icons = {
          notification = "󱅫";
          none = "󰂚";
          dnd-notification = "󰂛";
          dnd-none = "󰂛";
          inhibited-notification = "󰂛";
          inhibited-none = "󰂛";
          dnd-inhibited-notification = "󰂛";
          dnd-inhibited-none = "󰂛";
        };
        tooltip = false;
        on-click = "${lib.getExe' config.services.swaync.package "swaync-client"} -t -sw";
        on-click-right = "${lib.getExe' config.services.swaync.package "swaync-client"} -d -sw";
      };

      "custom/power" = {
        format = "󰐥";
        tooltip = false;
        on-click = "${lib.getExe pkgs.wlogout} --protocol layer-shell --buttons-per-row 3";
      };
    };
  };
}
