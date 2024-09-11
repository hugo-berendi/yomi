{
  lib,
  config,
  ...
}: let
  cfg = config.yomi;
in {
  options.yomi = {
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
