{pkgs, ...}: {
  programs.waybar = {
    enable = true;
    package = pkgs.waybar;

    # systemd.enable = true;
    # systemd.target = "hyprland-session.target";
  };

  stylix.targets.waybar = {enable = false;};
}
