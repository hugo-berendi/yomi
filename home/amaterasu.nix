{
  pkgs,
  upkgs,
  ...
}: {
  imports = [
    ./global.nix

    ./features/desktop/firefox
    ./features/desktop/discord
    ./features/desktop/wakatime
    ./features/desktop/spotify.nix
    ./features/desktop/obsidian.nix
    ./features/desktop/zathura.nix
    ./features/desktop/gaming.nix
    ./features/desktop/unity.nix
    ./features/wayland/hyprland
    ./features/productivity
  ];
  home = {
    file = {};
    sessionVariables = {EDITOR = "nvim";};
    packages = with pkgs; [
      localsend

      prismlauncher
      thunderbird
      thefuck
      sxiv
      signal-desktop
      qbittorrent
      # upkgs.unityhub
      upkgs.overskride
      # upkgs.nerdfetch # for displaying pc/laptop stats
      upkgs.alejandra # nix formatter
      upkgs.nh
      upkgs.nix-output-monitor
      upkgs.nvd

      lutris

      gtk3 # needed for gtk-launch

      # {{{ Clis
      sops # Secret editing
      # sherlock # Search for usernames across different websites
      # }}}
      # {{{ Media playing/recording
      mpv # Video player
      imv # Image viewer
      # peek # GIF recorder
      # obs-studio # video recorder
      # }}}

      # {{{ java development
      jetbrains.idea-ultimate
      jetbrains.jdk
      # }}}

      trayscale
    ];
  };

  home.sessionVariables.QT_SCREEN_SCALE_FACTORS = 1.4; # Bigger text in qt apps

  yomi.toggles.isServer.enable = false;

  services.trayscale.enable = true;

  yomi = {
    # Symlink some commonly modified dotfiles outside the nix store
    dev.enable = true;

    monitors = [
      {
        name = "eDP-1";
        width = 2256;
        height = 1504;
      }
    ];
  };
}
