{
  pkgs,
  upkgs,
  ...
}: {
  imports = [
    ./global.nix
    ./features/desktop/wakatime
  ];
  home = {
    file = {};
    sessionVariables = {EDITOR = "nvim";};
    packages = with pkgs; [
      pay-respects
      sxiv
      # upkgs.unityhub
      upkgs.overskride
      # upkgs.nerdfetch # for displaying pc/laptop stats
      upkgs.alejandra # nix formatter
      upkgs.nh
      upkgs.nix-output-monitor
      upkgs.nvd

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

  yomi.toggles.isServer.enable = true;
}
