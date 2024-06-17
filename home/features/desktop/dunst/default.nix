{
  services.dunst = {
    enable = true;

    settings = {
      global = {
        icon_path = "/usr/share/icons/gnome/16x16/status/:/usr/share/icons/gnome/16x16/devices/";
        monitor = 0;
        follow = "none";
        width = 500;
        height = 400;
        origin = "bottom-right";
        offset = "20x20";
        scale = 0;
        notification_limit = 0;
        progress_bar = true;
        progress_bar_height = 10;
        progress_bar_frame_width = 1;
        progress_bar_min_width = 150;
        progress_bar_max_width = 300;
        indicate_hidden = true;
        transparency = 15;
        separator_height = 2;
        padding = 15;
        horizontal_padding = 15;
        text_icon_padding = 0;
        frame_width = 3;
        frame_color = "#89B4FA";
        gap_size = 5;
        seperator_color = "frame";
        sort = true;
        font = "Maple Mono NF 15";
        line_height = 0;
        markup = "full";
        format = "<b>%s</b>\n%b";
        alignment = "left";
        vertical_alignment = "center";
        show_age_threshold = 60;
        ellipsize = "middle";
        ignore_newline = false;
        stack_duplicates = true;
        hide_duplicate_count = false;
        show_indicators = true;
        enable_recursive_icon_lookup = true;
        icon_theme = "Adawaita";
        icons_position = "left";
        min_icon_size = 32;
        max_icon_size = 128;
        sticky_history = true;
        history_length = 20;
        browser = "xdg-open";
        always_run_script = true;
        title = "Dunst";
        class = "Dunst";
        corner_radius = 20;
        ignore_radius = 20;
        ignore_dbusclose = false;
        force_xwayland = false;
        force_xinerama = false;
        mouse_left_click = "close_current";
        mouse_middle_click = "do_action, close_current";
        mouse_right_click = "close_all";
      };

      exaperimental = {
        per_monitor_dpi = false;
      };

      urgency_low = {
        background = "#1E1E1E";
        foreground = "#CDD6F4";
        timeout = 10;
      };

      uregency_normal = {
        background = "#1E1E1E";
        foreground = "#CDD6F4";
        timeout = 10;
      };

      urgency_critical = {
        background = "#1E1E1E";
        foreground = "#CDD6F4";
        frame_color = "#FAB387";
        timeout = 10;
      };
    };
  };
  stylix.targets.dunst.enable = false;
  stylix.targets.hyprland.enable = true;
}
