{pkgs, ...}: {
  home.packages = with pkgs; [
    bun
  ];

  programs.ags = {
    enable = false;

    configDir = ./config;

    extraPackages = with pkgs; [
      gtksourceview
      webkitgtk
      accountsservice
    ];
  };
}
