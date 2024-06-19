{pkgs, ...}: {
  home.packages = with pkgs; [
    unstable.neovim
    unstable.neovide
  ];

  xdg.configFile."nvim".source = ./config;
}
