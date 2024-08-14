# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example' or (legacy) 'nix-build -A example'
pkgs: let
  plymouthThemes = pkgs.callPackage (import ./plymouth-themes.nix) {};
in {
  # example = pkgs.callPackage (import ./example.nix) {};
  # vimclip = pkgs.callPackage (import ./vimclip.nix) { };
  # homer = pkgs.callPackage (import ./homer.nix) { };

  plymouthThemeLone = plymouthThemes.lone;
  hyprpicker-new = pkgs.callPackage (import ./hyprpicker.nix) {};
  vimclip = pkgs.callPackage (import ./vimclip.nix) {};
}
