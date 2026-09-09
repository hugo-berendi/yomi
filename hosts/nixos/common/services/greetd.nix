{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.yomi.machine.graphical;
  colors = config.lib.stylix.colors.withHashtag;
  rgb = config.yomi.theming.colors.rgb;
  greeterConfig = pkgs.writeText "nwg-hello.json" (builtins.toJSON {
    session_dirs = [
      "/run/current-system/sw/share/wayland-sessions"
      "/run/current-system/sw/share/xsessions"
    ];
    custom_sessions = [];
    monitor_nums = [];
    form_on_monitors = [];
    delay_secs = 1;
    cmd-sleep = "systemctl suspend";
    cmd-reboot = "systemctl reboot";
    cmd-poweroff = "systemctl poweroff";
    gtk-theme = "Adwaita";
    gtk-icon-theme = "Papirus-Dark";
    gtk-cursor-theme = config.stylix.cursor.name;
    prefer-dark-theme = true;
    template-name = "";
    time-format = "%H:%M";
    date-format = "%A, %d. %B";
    layer = "overlay";
    keyboard-mode = "on_demand";
    lang = "de_DE.UTF-8";
    avatar-show = true;
    avatar-size = 104;
    avatar-border-width = 2;
    avatar-border-color = colors.base0D;
    avatar-corner-radius = 52;
    avatar-circle = true;
    env-vars = ["XCURSOR_SIZE=${toString config.stylix.cursor.size}"];
  });
  greeterStyle = pkgs.writeText "nwg-hello.css" ''
    * {
      font-family: "${config.stylix.fonts.sansSerif.name}";
      color: ${colors.base05};
    }

    window {
      background-image: linear-gradient(rgba(${rgb "base00"}, 0.28), rgba(${rgb "base00"}, 0.5)), url("${config.stylix.image}");
      background-size: cover;
      background-position: center;
    }

    #form-wrapper {
      background-color: rgba(${rgb "base00"}, 0.7);
      border: 2px solid rgba(${rgb "base0D"}, 0.72);
      border-radius: 24px;
      padding: 28px;
      box-shadow: 0 12px 36px rgba(${rgb "base00"}, 0.58);
    }

    entry,
    button,
    combobox button {
      background: rgba(${rgb "base01"}, 0.76);
      border: 1px solid rgba(${rgb "base0D"}, 0.58);
      border-radius: 14px;
      padding: 12px 16px;
    }

    entry:focus,
    button:hover,
    combobox button:hover {
      background: rgba(${rgb "base02"}, 0.9);
      border-color: ${colors.base0D};
    }

    #login-button {
      color: ${colors.base00};
      background: ${colors.base0D};
      font-weight: 700;
    }

    #power-button {
      background: transparent;
      border: none;
    }

    #power-button:hover {
      background: rgba(${rgb "base02"}, 0.72);
    }

    #welcome-label {
      color: ${colors.base06};
      font-size: 42px;
      font-weight: 700;
    }

    #clock-label {
      color: ${colors.base06};
      font-size: 34px;
      font-weight: 700;
    }

    #date-label {
      color: ${colors.base04};
      font-size: 16px;
    }
  '';
  greeterCommand = lib.escapeShellArgs [
    (lib.getExe pkgs.nwg-hello)
    "--config"
    greeterConfig
    "--stylesheet"
    greeterStyle
  ];
  greeterHyprlandConfig = pkgs.writeText "nwg-hello-hyprland.conf" ''
    monitor = , preferred, auto, 1
    animations {
      enabled = false
    }
    misc {
      disable_hyprland_logo = true
      disable_splash_rendering = true
    }
    exec-once = ${greeterCommand}; hyprctl dispatch exit
  '';
in {
  config = lib.mkIf cfg {
    services.greetd = {
      enable = true;
      useTextGreeter = false;
      settings.default_session = {
        command = "${lib.getExe pkgs.hyprland} --config ${greeterHyprlandConfig}";
        user = "greeter";
      };
    };

    services.accounts-daemon.enable = true;
    environment.systemPackages = [pkgs.nwg-hello];
  };
}
