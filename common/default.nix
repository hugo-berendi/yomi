# This directory contains modules which can be loaded on both nixos and home-manager!
{
  imports = [
    ./fonts.nix
    ./themes
    ./nixpkgs.nix
  ];

  # {{{ ad-hoc toggles
  yomi.toggles.neovim-nightly.enable = true;
  # }}}
}
