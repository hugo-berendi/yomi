{
  transparency,
  base16,
  ...
}: {
  stylix = {
    base16Scheme = base16 "catppuccin-latte";
    opacity = transparency 0.6;
    polarity = "light";
  };
  yomi = {
    gaps = {
      outer = 20;
      inner = 5;
    };
    rounding = {
      radius = 10;
      size = 2;
    };
    blur = {
      passes = 2;
      size = 7;
    };
  };
}
