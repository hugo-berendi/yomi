{
  transparency,
  base16,
  ...
}: {
  stylix = {
    image = ./wallpapers/synth-city.jpg;
    base16Scheme = base16 "mellow-purple";
    opacity = transparency 0.5;
    polarity = "dark";
  };
  yomi = {
    gaps = {
      outer = 20;
      inner = 5;
    };
    rounding = {
      radius = 5;
      size = 2;
    };
    blur = {
      passes = 3;
      size = 7;
    };
  };
}
