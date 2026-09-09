# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example' or (legacy) 'nix-build -A example'
{pkgs ? (import ../nixpkgs.nix) {}, ...}: {
  vimclip = pkgs.callPackage (import ./vimclip.nix) {};
  pelican-wings = pkgs.callPackage ./pelican-wings.nix {};
  komf = pkgs.callPackage ./komf.nix {};
  chatgpt = pkgs.callPackage ./chatgpt.nix {};
  helium = pkgs.callPackage ./helium.nix {};
  hermes-mcp-changedetection = pkgs.callPackage ./hermes-mcp-changedetection {};
  hermes-mcp-radicale = pkgs.callPackage ./hermes-mcp-radicale {};
}
