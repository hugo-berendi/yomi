{
  pkgs,
  config,
  ...
}: let
  calibre_config_dir = "${config.xdg.configHome}/calibre"; # Config options
in {
  home = {
    packages = with pkgs; [calibre libsForQt5.qt5ct];
    sessionVariables = {
      CALIBRE_USE_SYSTEM_THEME = 1;
      QT_QPA_PLATFORM = "wayland";
      CALIBRE_CONFIG_DIRECTORY =
        calibre_config_dir;
    };

    file.".config/qt5ct/colors/Base16.conf".text = ''
      [ColorScheme]
        active_colors=#ff${config.lib.stylix.scheme.base05}, #ff${config.lib.stylix.scheme.base00}, #ff${config.lib.stylix.scheme.base0E}, #ff${config.lib.stylix.scheme.base03}, #ff${config.lib.stylix.scheme.base03}, #ff${config.lib.stylix.scheme.base04}, #ff${config.lib.stylix.scheme.base05}, #ff${config.lib.stylix.scheme.base05}, #ff${config.lib.stylix.scheme.base05}, #ff${config.lib.stylix.scheme.base00}, #ff${config.lib.stylix.scheme.base01}, #ff${config.lib.stylix.scheme.base0D}, #ff${config.lib.stylix.scheme.base0D}, #ff${config.lib.stylix.scheme.base00}, #ff${config.lib.stylix.scheme.base0D}, #ff${config.lib.stylix.scheme.base08}, #ff${config.lib.stylix.scheme.base00}, #ff${config.lib.stylix.scheme.base05}, #ff${config.lib.stylix.scheme.base01}, #ff${config.lib.stylix.scheme.base05}, #ff${config.lib.stylix.scheme.base04}
        disabled_colors=#ff${config.lib.stylix.scheme.base0E}, #ff${config.lib.stylix.scheme.base00}, #ff${config.lib.stylix.scheme.base0E}, #ff${config.lib.stylix.scheme.base03}, #ff${config.lib.stylix.scheme.base03}, #ff${config.lib.stylix.scheme.base04}, #ff${config.lib.stylix.scheme.base0E}, #ff${config.lib.stylix.scheme.base0E}, #ff${config.lib.stylix.scheme.base0E}, #ff${config.lib.stylix.scheme.base00}, #ff${config.lib.stylix.scheme.base01}, #ff${config.lib.stylix.scheme.base0D}, #ff${config.lib.stylix.scheme.base0D}, #ff${config.lib.stylix.scheme.base03}, #ff${config.lib.stylix.scheme.base0D}, #ff${config.lib.stylix.scheme.base08}, #ff${config.lib.stylix.scheme.base00}, #ff${config.lib.stylix.scheme.base05}, #ff${config.lib.stylix.scheme.base01}, #ff${config.lib.stylix.scheme.base05}, #ff${config.lib.stylix.scheme.base04}
        inactive_colors=#ff${config.lib.stylix.scheme.base05}, #ff${config.lib.stylix.scheme.base00}, #ff${config.lib.stylix.scheme.base0E}, #ff${config.lib.stylix.scheme.base03}, #ff${config.lib.stylix.scheme.base03}, #ff${config.lib.stylix.scheme.base04}, #ff${config.lib.stylix.scheme.base05}, #ff${config.lib.stylix.scheme.base05}, #ff${config.lib.stylix.scheme.base05}, #ff${config.lib.stylix.scheme.base00}, #ff${config.lib.stylix.scheme.base01}, #ff${config.lib.stylix.scheme.base0D}, #ff${config.lib.stylix.scheme.base0D}, #ff${config.lib.stylix.scheme.base0E}, #ff${config.lib.stylix.scheme.base0D}, #ff${config.lib.stylix.scheme.base08}, #ff${config.lib.stylix.scheme.base00}, #ff${config.lib.stylix.scheme.base05}, #ff${config.lib.stylix.scheme.base01}, #ff${config.lib.stylix.scheme.base05}, #ff${config.lib.stylix.scheme.base04}

    '';
  };
  yomi.persistence.at.state.apps.calibre.directories = [
    calibre_config_dir
  ];

  qt = {
    enable = true;
    platformTheme.name = "gtk3";
  };
}
