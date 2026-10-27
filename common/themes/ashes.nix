{
  transparency,
  pkgs,
  ...
}: {
  stylix = {
    image = ./wallpapers/samurai-dark.jpg;
    opacity = transparency 0.5;
    polarity = "dark";
    cursor = {
      package = pkgs.phinger-cursors;
      name = "phinger-cursors-dark";
      size = 20;
    };
  };
  yomi = {
    gaps = {
      outer = 20;
      inner = 5;
    };
    rounding = {
      radius = 15;
      size = 3;
    };
    blur = {
      passes = 2;
      size = 7;
    };
  };
}
