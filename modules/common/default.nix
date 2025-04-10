# (https://nixos.wiki/wiki/Module).
{
  # example = import ./example.nix;
  lua-lib = import ./lua-lib.nix;
  lua-colorscheme = import ./lua-colorscheme.nix;
  theming = import ./theming.nix;
  themes = import ./themes.nix;
  toggles = import ./toggles.nix;
}
