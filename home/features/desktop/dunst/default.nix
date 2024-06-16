{
  services.dunst = {
    enable = true;
    configFile = ./dunstrc;
    settings.global.icon_path = "/home/hugob/dotfiles/nix-config/home/features/desktop/dunst/icons";
  };
  stylix.targets.dunst.enable = false;
  stylix.targets.hyprland.enable = true;
}
