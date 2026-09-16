# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example' or (legacy) 'nix-build -A example'
{
  pkgs ? (import ../nixpkgs.nix) {},
  upkgs ? pkgs,
  ...
}: {
  vimclip = pkgs.callPackage (import ./vimclip.nix) {};
  pelican-wings = pkgs.callPackage ./pelican-wings.nix {};
  chatgpt = pkgs.callPackage ./chatgpt.nix {};
  helium = pkgs.callPackage ./helium.nix {};
  suwayomi-server = pkgs.callPackage ./suwayomi-server.nix {};
  cliproxyapi-copilot-plugin = upkgs.callPackage ./cliproxyapi-copilot-plugin.nix {};
}
