{
  config,
  inputs,
  pkgs,
  ...
}: {
  yomi.settings = {
    terminal = "ghostty";
    terminal-cmd = "ghostty";
  };
  home.packages = [
    inputs.ghostty-pkg.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
  xdg.configFile."ghostty/config".text = ''
    font-size = ${toString config.stylix.fonts.sizes.terminal}
    font-family = Iosevka Term Nerd Font
    theme = cloudcore
    background-opacity = ${toString config.stylix.opacity.terminal}
    background-blur-radius = 7
  '';
}
