{
  transparency,
  base16,
  ...
}: {
  stylix = {
    image = ./wallpapers/sketchy-peaks.png;
    base16Scheme = base16 "gruvbox-light-soft";
    opacity = transparency 0.7;
    polarity = "light";
  };
  yomi.rounding.radius = 8;

  # For this one, I went with a big size, which means the blur just adds a slight gradient to the backgrounds.
  yomi.blur = {
    brightness = 1.05;
    size = 25.0;
  };
}
