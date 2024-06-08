{pkgs, ...}: {
  programs.waybar = {
    enable = false;
    package = pkgs.old.waybar;

    systemd.enable = true;
    systemd.target = "hyprland-session.target";
  };

  stylix.targets.waybar = {enable = false;};
}
