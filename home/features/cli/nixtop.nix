# nixtop: a system monitor built for NixOS (store-path aware processes,
# running builds, generations, store size). Installed next to btop rather than
# replacing it.
{inputs, ...}: {
  imports = [inputs.nixtop.homeManagerModules.default];

  programs.nixtop = {
    enable = true;
    # Stylix targets are opted into explicitly here (see btop in default.nix),
    # so say it rather than rely on the module following stylix.enable.
    stylix.enable = true;
  };
}
