{pkgs, ...}: {
  # {{{ Imports
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
  # }}}
  # {{{ Services
  services.batsignal.enable = true;

  services.gnome-keyring = {
    enable = true;
    components = ["pkcs11" "secrets" "ssh"];
  };
  # }}}
  # {{{ Theming
  stylix.targets.gtk.enable = true;

  gtk.iconTheme = {
    package = pkgs.papirus-icon-theme;
    name = "Papirus";
  };
  # }}}
  # {{{ Packages
  home.packages = with pkgs; [
    gimp
    krita
    libreoffice
    bitwarden
    qbittorrent
    overskride
    mpv
    imv
    obs-studio
  ];
  # }}}
}
