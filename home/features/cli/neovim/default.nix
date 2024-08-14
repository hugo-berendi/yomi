{pkgs, ...}: {
  home.packages = with pkgs; [
    unstable.neovim
    unstable.neovide
    vimclip
  ];

  xdg.configFile."nvim".source = ./config;
}
