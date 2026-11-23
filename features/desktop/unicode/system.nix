{
  pkgs,
  lib,
  config,
  ...
}: {
  config.i18n.inputMethod = lib.mkIf config.yomi.machine.graphical {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [
      fcitx5-gtk
      qt6Packages.fcitx5-configtool
    ];
    fcitx5.waylandFrontend = true;
  };
}
