{
  services.hypridle = {
    enable = true;
    importantPrefixes = [];
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock"; # Avoid starting multiple hyprlock instances.
        before_sleep_cmd = "loginctl lock-session"; # Lock before suspend.
        after_sleep_cmd = "hyprctl dispatch dpms on"; # To avoid having to press a key twice to turn on the display.
      };

      listener = [
        {
          timeout = 150; # 2.5min.
          on-timeout = "brightnessctl -s set 10"; # Set monitor backlight to minimum, avoid 0 on OLED monitor.
          on-resume = "brightnessctl -r"; # Monitor backlight restore.
        }
        # Turn off keyboard backlight, comment out this section if you don't have a keyboard backlight.
        # {
        #   timeout = 150; # 2.5min.
        #   on-timeout = "brightnessctl -sd rgb:kbd_backlight set 0"; # Turn off keyboard backlight.
        #   on-resume = "brightnessctl -rd rgb:kbd_backlight"; # Turn on keyboard backlight.
        # }
        {
          timeout = 300; # 5min.
          on-timeout = "loginctl lock-session"; # Lock screen when timeout has passed.
        }
        {
          timeout = 330; # 5.5min.
          on-timeout = "hyprctl dispatch dpms off"; # Screen off when timeout has passed.
          on-resume = "hyprctl dispatch dpms on"; # Screen on when activity is detected after timeout has fired.
        }
        {
          timeout = 1800; # 30min.
          on-timeout = "systemctl suspend"; # Suspend PC.
        }
      ];
    };
  };
}
