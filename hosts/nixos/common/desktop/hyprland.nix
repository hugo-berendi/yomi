# The main configuration is specified by home-manager
{
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.yomi.machine.graphical;
in {
  config = lib.mkIf cfg {
    security.pam.services.hyprlock = {};

    programs.hyprland = {
      enable = true;
      package = pkgs.hyprland;
    };

    environment.systemPackages = [config.programs.hyprland.package];
  };
}
