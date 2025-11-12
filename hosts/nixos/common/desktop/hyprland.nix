# The main configuration is specified by home-manager
{
  pkgs,
  inputs,
  ...
}: let
  cfg = config.yomi.hyprland;
in {
  options.yomi.hyprland = {
    enable = lib.mkEnableOption "yomi's hyprland integration";
  };

  config = lib.mkIf cfg.enable {
    assertion = [
      {
        message = "Hyprland can only be used on graphical machines";
        assertion = config.yomi.machine.graphical;
      }
    ];

    security.pam.services.hyprlock = {};

    programs.hyprland = {
      enable = true;
      package = pkgs.hyprland;
    };

    services.udev.packages = [pkgs.swayosd];

    environment.systemPackages = [config.programs.hyprland.package];
  };
}
