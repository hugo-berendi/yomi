{
  lib,
  config,
  ...
}: let
  cfg = config.satellite;
in {
  options.satellite = {
    themes = lib.mkOption {
      description = "List of all themes";
      type = lib.types.lazyAttrsOf lib.types.any;
      default = {};
    };
    currentTheme = lib.mkOption {
      description = "Current system theme";
      type = lib.types.submodule {
        options = cfg.themes;
      };
    };
  };
}
