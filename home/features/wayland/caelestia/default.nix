{config, ...}: {
  programs.caelestia = {
    enable = true;
    cli.enable = true;
    systemd.enable = true;

    settings = {
      appearance = {
        font = {
          family = {
            sans = config.stylix.fonts.sansSerif.name;
            mono = config.stylix.fonts.monospace.name;
            clock = config.stylix.fonts.serif.name;
          };
        };

        transparency = {
          enabled = true;
          base = config.stylix.opacity.applications;
        };
      };

      paths = {
        wallpaperDir = "${config.xdg.userDirs.pictures}/wallpapers";
      };

      services = {
        smartScheme = false;
      };

      launcher = {
        enableDangerousActions = false;
      };
    };
  };
}
