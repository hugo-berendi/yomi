{
  pkgs,
  config,
  inputs,
  ...
}: {
  programs.yazi = {
    enable = true;
    package = inputs.yazi.packages.${pkgs.system}.default;
    enableFishIntegration = true;
    theme = builtins.fromTOML (builtins.readFile ./theme.toml);
    settings = builtins.fromTOML (builtins.readFile ./yazi.toml);
    keymap = builtins.fromTOML (builtins.readFile ./keymap.toml);
  };

  home.file."${config.xdg.configHome}/yazi/plugins".source = ./plugins;
  home.file."${config.xdg.configHome}/yazi/flavors".source = ./flavors;
}
