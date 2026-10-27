# One file per theme; each takes the helpers from lib.nix plus the package sets
# it needs and returns { stylix; yomi; }. Only the theme named in currentTheme
# is applied, the rest are kept to switch to by hand.
{
  upkgs,
  pkgs,
  inputs,
  ...
}: let
  helpers = import ./lib.nix {inherit upkgs;};
  theme = file:
    import file (helpers // {inherit pkgs upkgs inputs;});

  themes = {
    catppuccin-mocha = theme ./catppuccin-mocha.nix;
    catppuccin-latte = theme ./catppuccin-latte.nix;
    catppuccin-macchiato = theme ./catppuccin-macchiato.nix;
    rosepine-dawn = theme ./rosepine-dawn.nix;
    rosepine-moon = theme ./rosepine-moon.nix;
    rose-pine = theme ./rose-pine.nix;
    ashes = theme ./ashes.nix;
    gruvbox-light = theme ./gruvbox-light.nix;
    gruvbox-dark = theme ./gruvbox-dark.nix;
    mellow-purple = theme ./mellow-purple.nix;
    cloudcore = theme ./cloudcore.nix;
  };

  currentTheme = themes.rosepine-moon;
in {
  # We apply the current theme here.
  # The rest is handled by the respective modules!
  imports = [
    {
      inherit (currentTheme) stylix;
      yomi.theming = currentTheme.yomi;
    }
  ];

  # Requires me to manually turn targets on!
  stylix = {
    enable = true;
    autoEnable = false;
  };
}
