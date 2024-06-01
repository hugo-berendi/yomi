{ pkgs, ... }: {
  stylix.fonts = {
    # monospace = { name = "Iosevka"; package = pkgs.iosevka; };
    monospace = { name = "Maple Mono NF"; package = pkgs.maple-mono-NF; };
    sansSerif = { name = "Maple Mono NF"; package = pkgs.maple-mono-NF; };
    serif = { name = "Maple Mono NF"; package = pkgs.maple-mono-NF; };

    sizes = {
      desktop = 13;
      applications = 15;
    };
  };
}
