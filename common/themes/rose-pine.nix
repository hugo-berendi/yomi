{
  transparency,
  base16,
  pkgs,
  ...
}: {
  stylix = {
    image = ./wallpapers/rosepine_creepy_moon.jpg;
    base16Scheme = base16 "rose-pine";
    opacity = transparency 0.7;
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
