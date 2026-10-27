# Packages and defaults that amaterasu, inari and the WSL hosts each used to
# list for themselves. Every host that imports home/global.nix gets them.
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
