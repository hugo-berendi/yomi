# This directory contains modules which can be loaded on both nixos and home-manager!
{
  imports = [./fonts.nix ./themes];

  # {{{ ad-hoc toggles
  yomi.toggles.neovim-nightly.enable = false;
  # }}}
}
