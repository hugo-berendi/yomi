# Packages and defaults that amaterasu, inari and the WSL hosts each used to
# list for themselves. Every host with Home Manager gets them through
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
