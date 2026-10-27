{
  config,
  lib,
  ...
}: let
  colors = config.lib.stylix.colors.withHashtag;
  theme = config.yomi.shellTheme;
in {
  options.yomi.shellTheme = {
    palette = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      description = "Semantic shell colors derived from the active Stylix scheme";
    };

    opacity = {
      panel = lib.mkOption {
        type = lib.types.float;
        description = "Opacity used by shell panels";
      };

      elevated = lib.mkOption {
        type = lib.types.float;
        description = "Opacity used by elevated shell surfaces";
      };

      muted = lib.mkOption {
        type = lib.types.float;
        description = "Opacity used by subdued shell elements";
      };
    };

    css = lib.mkOption {
      type = lib.types.functionTo lib.types.str;
      description = "Returns a shell palette color suitable for CSS";
    };

    rgba = lib.mkOption {
      type = lib.types.functionTo (lib.types.functionTo lib.types.str);
      description = "Returns a shell palette color with the requested CSS alpha value";
    };
  };

  config.yomi.shellTheme = {
    palette = {
      background = colors.base00;
      surface = colors.base01;
      surfaceRaised = colors.base02;
      overlay = colors.base03;
      muted = colors.base04;
      text = colors.base05;
      textStrong = colors.base06;
      bright = colors.base07;
      critical = colors.base08;
      warning = colors.base09;
      attention = colors.base0A;
      success = colors.base0B;
      info = colors.base0C;
      accent = colors.base0D;
      secondary = colors.base0E;
      special = colors.base0F;
    };

    opacity = {
      panel = config.stylix.opacity.desktop;
      elevated = config.stylix.opacity.popups;
      muted = 0.64;
    };

    css = name: theme.palette.${name};
    rgba = name: alpha: "rgba(${config.yomi.theming.colors.rgb (let
      semanticToBase16 = {
        background = "base00";
        surface = "base01";
        surfaceRaised = "base02";
        overlay = "base03";
        muted = "base04";
        text = "base05";
        textStrong = "base06";
        bright = "base07";
        critical = "base08";
        warning = "base09";
        attention = "base0A";
        success = "base0B";
        info = "base0C";
        accent = "base0D";
        secondary = "base0E";
        special = "base0F";
      };
    in
      semanticToBase16.${name})}, ${toString alpha})";
  };
}
