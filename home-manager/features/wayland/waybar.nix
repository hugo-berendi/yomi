{ ... }: {
  programs.waybar = {
    enable = true;

    # systemd.enable = true;
    # systemd.target = "hyprland-session.target";
  };

  stylix.targets.waybar = { enable = false; };
}
