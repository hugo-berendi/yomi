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

  home.shellAliases = let
    eza = lib.getExe package;
  in rec {
    ls = "${eza} --icons --long";
    la = "${ls} --all";
    lt = "${ls} --tree"; # Similar to tree, but also has --long!

    # I am used to using pkgs.tree, so this is nice to have!
    tree = "${eza} --icons --tree";
  };
}
