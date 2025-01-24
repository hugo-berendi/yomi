# This file defines overlays
{
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs {pkgs = final;};

  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = final: _prev: {
    # example = prev.example.overrideAttrs (oldAttrs: rec {
    # ...
    # });
    # glibc =
    #   (import (builtins.fetchGit {
    #       name = "glibc_2_39";
    #       url = "https://github.com/NixOS/nixpkgs/";
    #       ref = "refs/heads/nixpkgs-unstable";
    #       rev = "05bbf675397d5366259409139039af8077d695ce";
    #     }) {
    #       inherit (final) system;
    #     })
    #   .glibc;
  };
}
