{opkgs, ...}: {
  programs.waybar = {
    enable = false;
    package = opkgs.waybar;

    systemd.enable = true;
    systemd.target = "hyprland-session.target";
  };

  stylix.targets.waybar = {enable = false;};
}
