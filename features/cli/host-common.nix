# Packages and defaults every host with Home Manager shares, through
# features/default.nix.
{
  pkgs,
  upkgs,
  ...
}: {
  home = {
    sessionVariables.EDITOR = "nvim";
    packages = [
      pkgs.pay-respects
      pkgs.sxiv
      pkgs.sops # Secret editing
      pkgs.mpv # Video player
      pkgs.imv # Image viewer
      upkgs.nh
      upkgs.nix-output-monitor
      upkgs.nvd
    ];
  };
}
