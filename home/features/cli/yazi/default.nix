{
  pkgs,
  inputs,
  ...
}: {
  stylix.targets.yazi.enable = true;

  programs.yazi = {
    enable = true;
    package = inputs.yazi.packages.${pkgs.stdenv.hostPlatform.system}.default;
    enableFishIntegration = true;
    theme = builtins.fromTOML (builtins.readFile ./theme.toml);
    settings = builtins.fromTOML (builtins.readFile ./yazi.toml);
    keymap = builtins.fromTOML (builtins.readFile ./keymap.toml);
  };

  xdg.configFile = {
    "yazi/plugins".source = ./plugins;
    "yazi/flavors".source = ./flavors;
  };

  home.packages = with pkgs; [
    glow
    hexyl
    exiftool
    ouch
    transmission_4
    ripgrep
  ];
}
