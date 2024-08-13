{
  pkgs,
  lib,
  ...
}: let
  package = pkgs.eza;
in {
  programs.eza = {
    enable = true;
    enableFishIntegration = true;
  };
}
