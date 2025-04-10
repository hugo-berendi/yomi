# Additional theming primitives not provided by stylix
{
  lib,
  config,
  ...
}: let
  cfg = config.yomi.theming;
in {
  options.yomi.theming = {
    gaps = {
      enable = lib.mkEnableOption "gaps (padding / margin) for apps";
      inner = lib.mkOption {
        default = 0;
        type = lib.types.int;
      };
      outer = lib.mkOption {
        default = 0;
        type = lib.types.int;
      };
    };
    rounding = {
      # Note: this is automatically set to true when the radius is strictly positive
      enable = lib.mkEnableOption "rounded corners for desktop apps";
      radius = lib.mkOption {
        default = 0;
        type = lib.types.int;
      };
      size = lib.mkOption {
        default = 0;
        type = lib.types.int;
      };
    };

    # These pretty much directly map onto hypland options
    blur = {
      # Note: this is automatically set to true when the passes are strictly positive
      enable = lib.mkEnableOption "blurred backgrounds for desktop apps";

      passes = lib.mkOption {
        default = 4;
        type = lib.types.int;
      };
      brightness = lib.mkOption {
        default = 1;
        type = lib.types.int;
      };
      contrast = lib.mkOption {
        default = 1;
        type = lib.types.int;
      };
      size = lib.mkOption {
        default = 10;
        type = lib.types.int;
      };
    };

    get = lib.mkOption {
      # No generics:(
      # The type of this is essentially (written in ts-like -pseudocode):
      #
      # Record<String, T>
      #   & { default?: T | {light?: T, dark?: T } }
      #   -> Option<T>
      type = lib.types.functionTo lib.types.anything;
      description = "Index a theme map by the current theme";
    };

    colors = {
      rgb = lib.mkOption {
        type = lib.types.functionTo lib.types.str;
        description = "Returns comma separated rgb values for a color. To be used in css files:)";
      };

      rgb-attrs = lib.mkOption {
        type = lib.types.functionTo lib.types.attrs;
        description = "Returns attrset rgb values for a color.)";
      };

      rgba = lib.mkOption {
        type = lib.types.functionTo lib.types.str;
        description = ''
          Returns comma separated rgba values for a color.
          The transparency is taken from `options.yomi.theming.transparency`.
        '';
      };

      rgba-attrs = lib.mkOption {
        type = lib.types.functionTo lib.types.attrs;
        description = "Returns attrset rgba values for a color.)";
      };

      colorToRgb = lib.mkOption {
        type = lib.types.functionTo lib.types.str;
        description = ''
          Converts a color name (e.g., "base08") to an `rgb()` string.
          It extracts the hex value from `config.lib.stylix.colors.withHashtag` and converts it to an RGB string.
        '';
      };

      hexWithoutHash = lib.mkOption {
        type = lib.types.functionTo lib.types.str;
        description = "remove # from a hex color";
      };

      hexToRgb = lib.mkOption {
        type = lib.types.functionTo lib.types.str;
        description = "Converts a hex color (e.g., '#FF5733') to an `rgb()` string (e.g., 'rgb(255, 87, 51)').";
      };
    };
  };

  config.yomi.theming = {
    rounding.enable = cfg.rounding.radius > 0;
    blur.enable = cfg.blur.passes > 0;

    get = themeMap:
      themeMap.${config.lib.stylix.scheme.scheme}
      or themeMap.default.${config.stylix.polarity or "dark"}
      or themeMap.default
      or (throw "Theme ${config.lib.stylix.scheme.scheme} not found in theme map!");

    colors.rgb = color:
      builtins.concatStringsSep "," [
        config.lib.stylix.scheme."${color}-rgb-r"
        config.lib.stylix.scheme."${color}-rgb-g"
        config.lib.stylix.scheme."${color}-rgb-b"
      ];

    colors.rgb-attrs = color: {
      r = config.lib.stylix.scheme."${color}-rgb-r";
      g = config.lib.stylix.scheme."${color}-rgb-g";
      b = config.lib.stylix.scheme."${color}-rgb-b";
    };

    colors.rgba = color: "${cfg.colors.rgb color},${toString config.stylix.opacity.applications}";

    colors.rgba-attrs = color: {
      r = config.lib.stylix.scheme."${color}-rgb-r";
      g = config.lib.stylix.scheme."${color}-rgb-g";
      b = config.lib.stylix.scheme."${color}-rgb-b";
      a = config.stylix.opacity.applications;
    };

    colors.hexWithoutHash = hex: let
      # Remove the leading '#' if it exists
      hexWithoutHash =
        if builtins.substring 0 1 hex == "#"
        then builtins.substring 1 (builtins.stringLength hex - 1) hex
        else hex;
    in
      hexWithoutHash;

    # Convert a hex color code to an RGB string
    colors.hexToRgb = hex: "rgb(${cfg.colors.hexWithoutHash hex})";

    # Function to convert color name to rgb()
    colors.colorToRgb = colorName: let
      hexColor = config.lib.stylix.colors.withHashtag.${colorName};
    in
      cfg.colors.hexToRgb hexColor;
  };
}
