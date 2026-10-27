# (https://nixos.wiki/wiki/Module).
{
  pilot = import ./pilot.nix;
  shell-theme = import ./shell-theme.nix;
  theming = import ./theming.nix;
  terminal = import ./terminal.nix;
}
