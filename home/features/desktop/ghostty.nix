{
  config,
  pkgs,
  ...
}: {
  yomi.terminal = {
    command = "ghostty";
    execCommand = "ghostty";
  };
  home.packages = [
    pkgs.ghostty
  ];
  xdg.configFile."ghostty/config".text = ''
    theme = Rose Pine Moon
    font-size = ${toString config.stylix.fonts.sizes.terminal}
    font-family = ${config.stylix.fonts.monospace.name}
    background-opacity = ${toString config.stylix.opacity.terminal}
    background-blur-radius = 12
    window-padding-x = 14
    window-padding-y = 12
    cursor-style = block
    cursor-style-blink = false
  '';
}
