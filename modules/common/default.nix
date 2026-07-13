# (https://nixos.wiki/wiki/Module).
{
  lua-lib = import ./lua-lib.nix;
  lua-colorscheme = import ./lua-colorscheme.nix;
  theming = import ./theming.nix;
  themes = import ./themes.nix;
  toggles = import ./toggles.nix;
}
