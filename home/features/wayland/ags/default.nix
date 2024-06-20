{pkgs, ...}: {
  home.packages = with pkgs; [
    bun
  ];

  programs.ags = {
    enable = true;

    configDir = ./config;

    extraPackages = with pkgs; [
      gtksourceview
      webkitgtk
      accountsservice
    ];
  };
}
