{upkgs, ...}: {
  stylix.fonts = {
    monospace = {
      name = "Maple Mono NF";
      package = upkgs.maple-mono.NF;
    };
    sansSerif = {
      name = "Maple Mono NF";
      package = upkgs.maple-mono.NF;
    };
    serif = {
      name = "Quicksand";
      package = upkgs.quicksand;
    };

    sizes = {
      terminal = 13;
      desktop = 15;
      applications = 15;
    };
  };
}
