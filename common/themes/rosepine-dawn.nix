{
  transparency,
  base16,
  upkgs,
  ...
}: {
  stylix = {
    image = ./wallpapers/rosepine_light_field.png;
    base16Scheme = base16 "rose-pine-dawn";
    opacity = transparency 0.3;
    polarity = "light";
    cursor = {
      package = upkgs.rose-pine-cursor;
      name = "BreezeX-RoséPineDawn";
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
      size = 10;
    };
  };
}
