{pkgs, ...}: {
  stylix.fonts = {
    monospace = {
      name = "Maple Mono NF";
      package = pkgs.unstable.maple-mono-NF;
    };
    sansSerif = {
      name = "Maple Mono NF";
      package = pkgs.unstable.maple-mono-NF;
    };
    serif = {
      name = "Maple Mono NF";
      package = pkgs.unstable.maple-mono-NF;
    };

    sizes = {
      desktop = 13;
      applications = 15;
    };
  };
}
