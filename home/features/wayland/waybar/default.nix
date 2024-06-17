{pkgs, ...}: {
  programs.waybar = {
    enable = true;
    package = pkgs.waybar;
  };

  xdg.configFile."waybar".source = ./config;

  stylix.targets.waybar = {enable = false;};
}
