{config, ...}: {
  yomi.terminal = {
    command = "ghostty";
    execCommand = "ghostty";
  };
  programs.ghostty = {
    enable = true;
    # Keep the file-only behaviour of the hand-written module: ghostty injects its
    # own shell integration, and the bat syntax, systemd and dbus units are new.
    installBatSyntax = false;
    systemd.enable = false;
    enableBashIntegration = false;
    enableFishIntegration = false;
    enableZshIntegration = false;
    settings = {
      theme = "Rose Pine Moon";
      font-size = config.stylix.fonts.sizes.terminal;
      font-family = config.stylix.fonts.monospace.name;
      background-opacity = config.stylix.opacity.terminal;
      background-blur-radius = 12;
      window-padding-x = 14;
      window-padding-y = 12;
      cursor-style = "block";
      cursor-style-blink = false;
    };
  };
}
