{
  pkgs,
  lib,
  ...
}: {
  programs.yazi = {
    enable = true;
    enableFishIntegration = true;
    flavors = {rose-pine = ./rose-pine.tmTheme;};
    theme = lib.importToml ./theme.toml;
    settings = lib.importToml ./yazi.toml;
    keymaps = lib.importToml ./keymap.toml;
    plugins = {};
  };
}
