# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example' or (legacy) 'nix-build -A example'
{pkgs ? (import ../nixpkgs.nix) {}, ...}: let
  plymouthThemes = pkgs.callPackage (import ./plymouth-themes.nix) {};
in rec {
  # example = pkgs.callPackage (import ./example.nix) {};
  hyprpicker-new = pkgs.callPackage (import ./hyprpicker.nix) {};
  vimclip = pkgs.callPackage (import ./vimclip.nix) {};
  homer = pkgs.callPackage (import ./homer.nix) {};
  octodns-cloudflare = pkgs.python3Packages.callPackage (import ./octodns-cloudflare.nix) {};
  # calibre-web-automated = pkgs.python3Packages.callPackage (import ./calibre-web-automated.nix) {};
  plymouthThemeLone = plymouthThemes.lone;
  zen-browser-unwrapped = pkgs.callPackage ./zen-browser-unwrapped {};
  zen-browser-bin = pkgs.wrapFirefox zen-browser-unwrapped {};
}
