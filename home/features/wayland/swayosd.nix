{
  config,
  pkgs,
  ...
}: let
  shell = config.yomi.shellTheme;
  radius = toString config.yomi.theming.rounding.radius;
  style = pkgs.writeText "swayosd-style.css" ''
    window#osd {
      border: ${toString config.yomi.theming.rounding.size}px solid ${shell.rgba "accent" 0.56};
      border-radius: ${radius}px;
      background: ${shell.rgba "background" shell.opacity.elevated};
    }

    window#osd #container {
      margin: 14px;
    }

    window#osd image,
    window#osd label {
      color: ${shell.palette.textStrong};
    }

    window#osd progressbar:disabled,
    window#osd image:disabled {
      opacity: ${toString shell.opacity.muted};
    }

    window#osd progressbar trough {
      min-height: 8px;
      border-radius: ${radius}px;
      background: ${shell.palette.surfaceRaised};
    }

    window#osd progressbar progress {
      min-height: 8px;
      border-radius: ${radius}px;
      background: ${shell.palette.accent};
    }
  '';
in {
  services.swayosd = {
    enable = true;
    topMargin = 0.84;
    stylePath = style;
  };
}
