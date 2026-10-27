{
  transparency,
  base16,
  ...
}: {
  stylix = {
    image = ./wallpapers/sad_hikari.png;
    base16Scheme = base16 "gruvbox-dark-soft";
    opacity = transparency 0.7;
    polarity = "dark";
  };
  yomi.rounding.radius = 8;
}
