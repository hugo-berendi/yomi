{
  config,
  pkgs,
  ...
}: {
  # {{{ Imports
  imports = [
    ./teams.nix
    ./karere.nix
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

  # What the settings portal answers when an app asks whether to go dark.
  # The stylix gtk target themes GTK widgets but leaves this unset, so the
  # portal reported "no preference" and everything that follows the system
  # rather than GTK -- Thunderbird, Teams, karere's WhatsApp page, T3 Code's
  # "system" mode -- rendered light beside a dark desktop.
  dconf.settings."org/gnome/desktop/interface".color-scheme =
    if config.stylix.polarity == "light"
    then "prefer-light"
    else "prefer-dark";

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
    qbittorrent
    overskride
    mpv
    imv
    obs-studio
  ];
  # }}}
}
