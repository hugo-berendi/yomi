{
  pkgs,
  lib,
  inputs,
  ...
}: {
  programs.yazi = {
    enable = true;
    package = inputs.yazi.packages.${pkgs.system}.default;
    enableFishIntegration = true;
    flavors = {rose-pine = ./rose-pine.tmTheme;};
    theme = builtins.fromToml (builtins.readFile ./theme.toml);
    settings = builtins.fromToml (builtins.readFile ./yazi.toml);
    keymaps = builtins.fromToml (builtins.readFile ./keymap.toml);
  };

  xdg.configFile."yazi/plugins".source = ./plugins;
}
