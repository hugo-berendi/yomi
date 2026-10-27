{
  transparency,
  base16,
  ...
}: {
  stylix = {
    image = ./wallpapers/gabriel.jpg;
    base16Scheme = base16 "catppuccin-macchiato";
    opacity = transparency 0.4;
    polarity = "dark";
  };
  yomi = {
    gaps = {
      outer = 20;
      inner = 5;
    };
    rounding = {
      radius = 8;
      size = 3;
    };
    blur = {
      passes = 2;
      size = 7;
    };
  };
}
