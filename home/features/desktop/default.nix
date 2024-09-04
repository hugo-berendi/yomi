{pkgs, ...}: {
  imports = [
    # ./kitty # terminal
    ./foot.nix
    # ./dunst # notifaction handler
    ./mako.nix
  ];

  # Notifies on low battery percentages
  services.batsignal.enable = true;

  # Use a base16 theme for gtk apps!
  stylix.targets.gtk.enable = true;

  gtk.iconTheme = {
    package = pkgs.papirus-icon-theme;
    name = "Papirus";
  };
}
