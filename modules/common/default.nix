# (https://nixos.wiki/wiki/Module).
{
  pilot = import ./pilot.nix;
  theming = import ./theming;
  terminal = import ./terminal.nix;
}
