{upkgs, ...}: let
  transparency = amount: {
    desktop = amount;
    applications = amount;
    terminal = amount;
    popups = amount;
  };

  base16 = name: "${upkgs.base16-schemes}/share/themes/${name}.yaml";

  themes = {
    # {{{ Catppuccin mocha
    catppuccin-mocha = {
      stylix = {
        image = ./wallpapers/breaking_phos.jpg;
        base16Scheme = base16 "catppuccin-mocha";
        opacity = transparency 0.7;
        polarity = "dark";
      };
      satellite = {
        gaps = {
          outer = 20;
          inner = 5;
        };
        rounding = {
          enable = true;
          radius = 8;
          size = 3;
        };
        blur = {
          passes = 2;
          size = 7;
        };
      };
    };
    # }}}
    # {{{ Catppuccin latte
    catppuccin-latte = {
      stylix = {
        image = ./wallpapers/field_diamond.jpg;
        base16Scheme = base16 "catppuccin-latte";
        opacity = transparency 0.6;
        polarity = "light";
      };
      satellite = {
        gaps = {
          outer = 20;
          inner = 5;
        };
        rounding = {
          enable = true;
          radius = 10;
          size = 2;
        };
        blur = {
          passes = 2;
          size = 7;
        };
      };
    };
    # }}}
    # {{{ Catppuccin macchiato
    catppuccin-macchiato = {
      stylix = {
        image = ./wallpapers/gabriel.jpg;
        base16Scheme = base16 "catppuccin-macchiato";
        opacity = transparency 0.4;
        polarity = "dark";
      };
      satellite = {
        gaps = {
          outer = 20;
          inner = 5;
        };
        rounding = {
          enable = true;
          radius = 8;
          size = 3;
        };
        blur = {
          passes = 2;
          size = 7;
        };
      };
    };
    # }}}
    # {{{ Rosepine dawn
    rosepine-dawn = {
      stylix = {
        image = ./wallpapers/rosepine_light_field.png;
        base16Scheme = base16 "rose-pine-dawn";
        opacity = transparency 0.3;
        polarity = "light";
        cursor = {
          package = upkgs.rose-pine-cursor;
          name = "BreezeX-RoséPineDawn";
        };
      };
      satellite = {
        gaps = {
          outer = 20;
          inner = 5;
        };
        rounding = {
          enable = true;
          radius = 15;
          size = 3;
        };
        blur = {
          passes = 2;
          size = 10;
        };
      };
    };
    # }}}
    # {{{ Rosepine moon
    rosepine-moon = {
      stylix = {
        image = ./wallpapers/rosepine_creepy_moon.jpg;
        base16Scheme = base16 "rose-pine-moon";
        opacity = transparency 0.5;
        polarity = "dark";
        cursor = {
          package = upkgs.rose-pine-cursor;
          # name = "BreezeX-RoséPine";
        };
      };
      satellite = {
        gaps = {
          outer = 20;
          inner = 5;
        };
        rounding = {
          enable = true;
          radius = 15;
          size = 3;
        };
        blur = {
          passes = 2;
          size = 7;
        };
      };
    };
    # }}}

    # {{{ Gruvbox light
    gruvbox-light = {
      stylix = {
        image = ./wallpapers/sketchy-peaks.png;
        base16Scheme = base16 "gruvbox-light-soft";
        opacity = transparency 0.7;
        polarity = "light";
      };
      satellite.rounding.radius = 8;

      # For this one, I went with a big size, which means the blur just adds a slight gradient to the backgrounds.
      satellite.blur = {
        brightness = 1.05;
        size = 25.0;
      };
    };
    # }}}
    # {{{ Gruvbox dark
    gruvbox-dark = {
      stylix = {
        image = ./wallpapers/sad_hikari.png;
        base16Scheme = base16 "gruvbox-dark-soft";
        opacity = transparency 0.7;
        polarity = "dark";
      };
      satellite.rounding.radius = 8;
    };
    # }}}
    # {{{ mellow-purple
    mellow-purple = {
      stylix = {
        image = ./wallpapers/synth-city.jpg;
        base16Scheme = base16 "mellow-purple";
        opacity = transparency 0.5;
        polarity = "dark";
      };
      satellite = {
        gaps = {
          outer = 20;
          inner = 5;
        };
        rounding = {
          enable = true;
          radius = 5;
          size = 2;
        };
        blur = {
          passes = 3;
          size = 7;
        };
      };
    };
  };

  currentTheme = themes.rosepine-moon;
in {
  # We apply the current theme here.
  # The rest is handled by the respective modules!
  imports = [
    {
      stylix = currentTheme.stylix;
      satellite.theming = currentTheme.satellite;
    }
  ];

  # Requires me to manually turn targets on!
  stylix = {
    enable = true;
    autoEnable = false;
  };
}
