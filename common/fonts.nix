{pkgs, ...}: {
  stylix.fonts = {
    monospace = {
      name = "Maple Mono NF";
      package = pkgs.maple-mono.NF;
    };
    sansSerif = {
      name = "Maple Mono NF";
      package = pkgs.maple-mono.NF;
    };
    serif = {
      name = "Maple Mono NF";
      package = pkgs.maple-mono.NF;
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
