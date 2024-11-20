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
    ./features/productivity
    # ./features/cli/lazygit.nix
    # ./features/cli/catgirl.nix
    # ./features/cli/nix-index.nix
    # ./features/cli/pass.nix
    ./features/wayland/hyprland
  ];


  yomi.toggles.isServer.enable = false;
  home = {
    file = {};
    sessionVariables = {EDITOR = "nvim";};
    packages = with pkgs; [
      biome
      localsend

      # prismlauncher
      # thunderbird
      # thefuck
      # nodejs
      # sxiv
      signal-desktop
      qbittorrent
      # upkgs.unityhub
      upkgs.overskride
      # upkgs.nerdfetch # for displaying pc/laptop stats
      upkgs.alejandra # nix formatter
      upkgs.nh
      upkgs.nix-output-monitor
      upkgs.nvd

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
    ];
  };

  home.sessionVariables.QT_SCREEN_SCALE_FACTORS = 1.4; # Bigger text in qt apps

  yomi = {
    # Symlink some commonly modified dotfiles outside the nix store
    dev.enable = true;

    monitors = [
      {
        name = "DP-1";
        width = 2560;
        height = 1440;
        refreshRate = 165;
        x = 0;
        y = 0;
      }
    ];
  };
}
