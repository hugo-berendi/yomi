{upkgs, ...}: {
  programs.waybar = {
    enable = true;
    package = upkgs.waybar;

    systemd.enable = true;
    systemd.target = "hyprland-session.target";
  };

  stylix.targets.waybar = {enable = false;};
}
