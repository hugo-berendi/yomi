# (https://nixos.wiki/wiki/Module).
{
  lua-lib = import ./lua-lib.nix;
  lua-colorscheme = import ./lua-colorscheme.nix;
  pilot = import ./pilot.nix;
  shell-theme = import ./shell-theme.nix;
  theming = import ./theming.nix;
  themes = import ./themes.nix;
  terminal = import ./terminal.nix;
  toggles = import ./toggles.nix;
}
