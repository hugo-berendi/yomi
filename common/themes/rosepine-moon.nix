{
  transparency,
  base16,
  pkgs,
  inputs,
  ...
}: {
  stylix = {
    image = ./wallpapers/rosepine_creepy_moon.jpg;
    base16Scheme = base16 "rose-pine-moon";
    opacity = transparency 0.86;
    polarity = "dark";
    cursor = {
      package = inputs.rose-pine-hyprcursor.packages.${pkgs.stdenv.hostPlatform.system}.default;
      name = "BreezX-RosePine-Linux";
      size = 36;
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
