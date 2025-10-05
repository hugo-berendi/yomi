{
  pkgs,
  config,
  ...
}: let
  calibre_config_dir = "${config.xdg.configHome}/calibre";
in {
  # {{{ Packages & environment
  home = {
    packages = with pkgs; [calibre libsForQt5.qt5ct];
    sessionVariables = {
      CALIBRE_USE_SYSTEM_THEME = 1;
      QT_QPA_PLATFORM = "wayland";
      CALIBRE_CONFIG_DIRECTORY = calibre_config_dir;
    };

    file.".config/qt5ct/colors/Base16.conf".text = ''
      [ColorScheme]
        active_colors=#ff${config.lib.stylix.colors.base05}, #ff${config.lib.stylix.colors.base00}, #ff${config.lib.stylix.colors.base0E}, #ff${config.lib.stylix.colors.base03}, #ff${config.lib.stylix.colors.base03}, #ff${config.lib.stylix.colors.base04}, #ff${config.lib.stylix.colors.base05}, #ff${config.lib.stylix.colors.base05}, #ff${config.lib.stylix.colors.base05}, #ff${config.lib.stylix.colors.base00}, #ff${config.lib.stylix.colors.base01}, #ff${config.lib.stylix.colors.base0D}, #ff${config.lib.stylix.colors.base0D}, #ff${config.lib.stylix.colors.base00}, #ff${config.lib.stylix.colors.base0D}, #ff${config.lib.stylix.colors.base08}, #ff${config.lib.stylix.colors.base00}, #ff${config.lib.stylix.colors.base05}, #ff${config.lib.stylix.colors.base01}, #ff${config.lib.stylix.colors.base05}, #ff${config.lib.stylix.colors.base04}
        disabled_colors=#ff${config.lib.stylix.colors.base0E}, #ff${config.lib.stylix.colors.base00}, #ff${config.lib.stylix.colors.base0E}, #ff${config.lib.stylix.colors.base03}, #ff${config.lib.stylix.colors.base03}, #ff${config.lib.stylix.colors.base04}, #ff${config.lib.stylix.colors.base0E}, #ff${config.lib.stylix.colors.base0E}, #ff${config.lib.stylix.colors.base0E}, #ff${config.lib.stylix.colors.base00}, #ff${config.lib.stylix.colors.base01}, #ff${config.lib.stylix.colors.base0D}, #ff${config.lib.stylix.colors.base0D}, #ff${config.lib.stylix.colors.base03}, #ff${config.lib.stylix.colors.base0D}, #ff${config.lib.stylix.colors.base08}, #ff${config.lib.stylix.colors.base00}, #ff${config.lib.stylix.colors.base05}, #ff${config.lib.stylix.colors.base01}, #ff${config.lib.stylix.colors.base05}, #ff${config.lib.stylix.colors.base04}
        inactive_colors=#ff${config.lib.stylix.colors.base05}, #ff${config.lib.stylix.colors.base00}, #ff${config.lib.stylix.colors.base0E}, #ff${config.lib.stylix.colors.base03}, #ff${config.lib.stylix.colors.base03}, #ff${config.lib.stylix.colors.base04}, #ff${config.lib.stylix.colors.base05}, #ff${config.lib.stylix.colors.base05}, #ff${config.lib.stylix.colors.base05}, #ff${config.lib.stylix.colors.base00}, #ff${config.lib.stylix.colors.base01}, #ff${config.lib.stylix.colors.base0D}, #ff${config.lib.stylix.colors.base0D}, #ff${config.lib.stylix.colors.base0E}, #ff${config.lib.stylix.colors.base0D}, #ff${config.lib.stylix.colors.base08}, #ff${config.lib.stylix.colors.base00}, #ff${config.lib.stylix.colors.base05}, #ff${config.lib.stylix.colors.base01}, #ff${config.lib.stylix.colors.base05}, #ff${config.lib.stylix.colors.base04}

    '';
  };
  # }}}
  # {{{ Qt config
  qt = {
    enable = true;
    platformTheme.name = "gtk3";
  };
  # }}}
  # {{{ Persistence
  yomi.persistence.at.state.apps.calibre.directories = [
    calibre_config_dir
  ];
  # }}}
}
