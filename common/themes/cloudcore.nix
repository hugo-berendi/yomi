{
  transparency,
  base16,
  pkgs,
  ...
}: {
  stylix = {
    image = ./wallpapers/samurai-dark.jpg;
    base16Scheme = base16 "everforest-dark-soft";
    opacity = transparency 1.0;
    polarity = "dark";
    cursor = {
      package = pkgs.phinger-cursors;
      name = "phinger-cursors-dark";
      size = 20;
    };
  };
  yomi = {
    gaps = {
      outer = 18;
      inner = 6;
    };
    rounding = {
      radius = 10;
      size = 3;
    };
    blur = {
      passes = 2;
      size = 8;
    };
  };
}
