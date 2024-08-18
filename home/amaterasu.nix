{pkgs, ...}: {
  imports = [
    ./global.nix

    ./features/desktop/firefox
    ./features/desktop/discord
    ./features/desktop/spotify.nix
    ./features/desktop/obsidian.nix
    ./features/desktop/zathura.nix
    # ./features/cli/productivity
    # ./features/cli/lazygit.nix
    # ./features/cli/catgirl.nix
    # ./features/cli/nix-index.nix
    # ./features/cli/pass.nix
    ./features/wayland/hyprland
  ];
  home = {
    file = {};
    sessionVariables = {EDITOR = "nvim";};
    packages = with pkgs; [
      biome
      localsend

      prismlauncher
      zoxide
      nwg-bar
      nwg-look
      thunderbird
      thefuck
      eza
      nodejs
      zathura
      sxiv
      mpv
      signal-desktop
      qbittorrent
      unstable.unityhub
      unstable.overskride
      # unstable.nerdfetch # for displaying pc/laptop stats
      unstable.alejandra # nix formatter
      unstable.nh
      unstable.nix-output-monitor
      unstable.nvd

      gtk3 # needed for gtk-launch
    ];
  };

  home.sessionVariables.QT_SCREEN_SCALE_FACTORS = 1.4; # Bigger text in qt apps

  satellite = {
    monitors = [
      {
        name = "eDP-1";
        width = 2256;
        height = 1504;
      }
    ];
  };
}
