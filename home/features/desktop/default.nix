{pkgs, ...}: {
  imports = [
    ./foot.nix
    ./ghostty.nix
    ./mako.nix
    ./discord
    ./firefox
    ./wakatime
    ./spotify.nix
    ./obsidian.nix
    ./zathura.nix
    ./gaming.nix
    ./unity.nix

    ./calibre.nix
  ];

  # Notifies on low battery percentages
  services.batsignal.enable = true;

  services.gnome-keyring = {
    enable = true;
    components = ["pkcs11" "secrets" "ssh"];
  };

  # Use a base16 theme for gtk apps!
  stylix.targets.gtk.enable = true;

  gtk.iconTheme = {
    package = pkgs.papirus-icon-theme;
    name = "Papirus";
  };

  # Base packages
  home.packages = with pkgs; [
    gimp # Image editing
    krita # drawing
    libreoffice # document editing
    bitwarden # Password-manager
    qbittorrent # Torrent client
    overskride # Bluetooth client
    mpv # Video player
    imv # Image viewer
    obs-studio # video recorder
  ];
}
