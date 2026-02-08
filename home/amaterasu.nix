{
  pkgs,
  upkgs,
  ...
}: {
  imports = [
    ./global.nix

    ./features/wayland/hyprland
    ./features/productivity
  ];

  # {{{ Fcitx5 keyboard configuration
  i18n.inputMethod.fcitx5.settings.inputMethod = {
    "Groups/0" = {
      Name = "Default";
      "Default Layout" = "de";
      DefaultIM = "keyboard-de";
    };
    "Groups/0/Items/0" = {
      Name = "keyboard-de";
      Layout = "";
    };
    GroupOrder = {
      "0" = "Default";
    };
  };
  # }}}

  home = {
    file = {};
    sessionVariables = {EDITOR = "nvim";};
    packages = with pkgs; [
      localsend

      prismlauncher
      thunderbird
      pay-respects
      sxiv
      # {{{ messaging
      signal-desktop
      teams-for-linux
      # }}}
      qbittorrent
      # upkgs.unityhub
      # upkgs.nerdfetch # for displaying pc/laptop stats
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
      # jetbrains.idea-ultimate
      # jetbrains.jdk
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
        name = "DP-2";
        width = 2560;
        height = 1440;
        refreshRate = 165;
        x = 0;
        y = 0;
        workspace = "1";
      }
      {
        name = "eDP-1";
        width = 2256;
        height = 1504;
        x = 2560;
        y = 0;
        workspace = "6";
      }
    ];
  };
}
