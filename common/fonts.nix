{upkgs, ...}: {
  stylix.fonts = {
    monospace = {
      name = "Iosevka Term Nerd Font";
      package = upkgs.iosevka-bin;
    };
    sansSerif = {
      name = "IBM Plex Sans";
      package = upkgs.ibm-plex;
    };
    serif = {
      name = "IBM Plex Serif";
      package = upkgs.ibm-plex;
    };

    sizes = {
      terminal = 12;
      desktop = 14;
      applications = 14;
    };
  };

  stylix.targets = {
    fontconfig.enable = true;
    font-packages.enable = true;
  };
}
