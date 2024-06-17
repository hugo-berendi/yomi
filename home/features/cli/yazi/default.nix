{
  pkgs,
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

  xdg.configFile = {
    "yazi/plugins".source = ./plugins;
    "yazi/flavors".source = ./flavors;
    # "yazi/plugins/glow.yazi/init.lua".source = ./plugins/glow.yazi/init.lua;
    # "yazi/flavors/rose-pine.yazi/rose-pine.tmTheme".source = ./flavors/rose-pine.yazi/rose-pine.tmTheme;
    # "yazi/flavors/rose-pine.yazi/theme.toml".source = ./flavors/rose-pine.yazi/theme.toml;
  };

  home.packages = with pkgs; [
    glow
  ];
}
