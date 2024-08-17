# The main configuration is specified by home-manager
{pkgs, ...}: {
  imports = [
    ./hyprlock.nix
  ];
  programs.hyprland = {
    enable = true;
    package = pkgs.hyprland;
    xwayland.enable = true;
  };
  services.udev.packages = [pkgs.swayosd];
}
