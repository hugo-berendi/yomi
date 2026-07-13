{
  lib,
  pkgs,
  config,
  ...
}: {
  config = lib.mkIf config.yomi.machine.graphical {
    services.dbus.enable = true;
    programs.dconf.enable = true;
    environment.systemPackages = [pkgs.xdg-utils];

    xdg.portal = {
      enable = true;
      xdgOpenUsePortal = true;
      extraPortals = [
        pkgs.xdg-desktop-portal-gtk
      ];
    };
  };
}
