{
  imports = [
    ./pipewire.nix
    ./quietboot.nix
    ./xdg-portal.nix
  ];

  stylix.targets.gtk.enable = true;
}
