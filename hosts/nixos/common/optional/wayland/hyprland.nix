# The main configuration is specified by home-manager
{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ./hyprlock.nix
  ];
  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    xwayland.enable = true;
  };
  services.udev.packages = [pkgs.swayosd];
}
