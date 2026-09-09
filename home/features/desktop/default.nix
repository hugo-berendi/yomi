{pkgs, ...}: {
  # {{{ Imports
  imports = [
    ./foot.nix
    ./ghostty.nix
    ./discord
    ./browser
    ./academic.nix
    ./wakatime
    ./spotify.nix
    ./obsidian.nix
    ./zathura.nix
    ./gaming.nix
    ./unity.nix
    ./calibre.nix
    ./chatgpt.nix
  ];
  # }}}
  # {{{ Services
  services.batsignal.enable = true;
  services.trayscale.enable = true;
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
    bitwarden-desktop
    karere
    qbittorrent
    overskride
    mpv
    imv
    obs-studio
  ];
  # }}}
}
