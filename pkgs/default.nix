# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example' or (legacy) 'nix-build -A example'
{
  pkgs ? (import ../nixpkgs.nix) {},
  upkgs ? pkgs,
  disko ? pkgs.disko,
  # Flake inputs; the overlay imports this file without them.
  inputs ? null,
  ...
}:
{
  yomi-recover = pkgs.callPackage ./yomi-recover {inherit disko;};
  diabetes-app = pkgs.callPackage ../hosts/nixos/inari/services/diabetes/package.nix {};
  vimclip = pkgs.callPackage ./vimclip.nix {};
  pelican-wings = pkgs.callPackage ./pelican-wings.nix {};
  chatgpt = pkgs.callPackage ./chatgpt.nix {};
  helium = pkgs.callPackage ./helium.nix {};
  suwayomi-server = pkgs.callPackage ./suwayomi-server.nix {};
  sockseek = pkgs.callPackage ./sockseek.nix {};
  audiomuse-navidrome-plugin = pkgs.callPackage ./audiomuse-navidrome-plugin.nix {};
  cliproxyapi-copilot-plugin = upkgs.callPackage ./cliproxyapi-copilot-plugin.nix {};
}
# A plain `if`: the overlay passes `final` as pkgs, and pkgs.lib here would
# make this attribute set's names depend on the fixpoint (infinite recursion).
// (
  if inputs == null
  then {}
  else {hermes-dispatcher = import ./hermes-dispatcher.nix {inherit pkgs inputs;};}
)
