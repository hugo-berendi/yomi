{
  upkgs,
  config,
  ...
}: let
  # Function to get the base16 scheme path for a theme variant
  base16SchemePath = themeName: "${upkgs.base16-schemes}/share/themes/${themeName}.yaml";

  # Define themes with their respective variants and default variants
  themes = {
    rose-pine = {
      variants = {
        moon = base16SchemePath "rose-pine-moon";
        dawn = base16SchemePath "rose-pine-dawn";
      };
      defaultVariant = "moon";
    };
    catppuccin = {
      variants = {
        mocha = base16SchemePath "catppuccin-mocha";
      };
      defaultVariant = "mocha";
    };
    # Add more themes here in the same format if needed
  };

  # Function to check if any variant of a theme is enabled
  isThemeEnabled = theme: builtins.elem config.stylix.base16Scheme (builtins.attrValues theme.variants);

  # Function to get the selected variant for a theme or fallback to the default
  selectedVariant = theme: let
    variantKeys = builtins.attrNames theme.variants; # Get the attribute keys (e.g., "moon", "dawn")
    matchKey =
      builtins.foldl' (
        acc: key:
          if acc != null || config.stylix.base16Scheme == theme.variants.${key}
          then key
          else acc
      )
      null
      variantKeys;
  in
    if matchKey != null
    then matchKey
    else theme.defaultVariant;

  # Determine if none of the themes are enabled
  noThemesEnabled = builtins.all (theme: !isThemeEnabled theme) (builtins.attrValues themes);
in {
  # {{{ nixvim theming
  stylix.targets.nixvim = {
    # Enable only if none of the themes are enabled
    enable = noThemesEnabled;

    transparentBackground = {
      main = true;
      signColumn = true;
    };
  };

  programs.nixvim = {
    colorschemes = {
      rose-pine = {
        # Enable only if a Rose Pine theme is selected
        enable = isThemeEnabled themes.rose-pine;
        settings = {
          styles = {
            bold = true;
            italic = true;
            transparency = true;
          };
          # Set the variant based on the selected Rose Pine theme
          variant = selectedVariant themes.rose-pine;
        };
      };
      catppuccin = {
        enable = isThemeEnabled themes.catppuccin;
        settings = {
          styles = {
            transparent_background = true;
          };
          flavour = selectedVariant themes.catppuccin;
        };
      };
      # Add more themes here, each with its specific attributes
    };
  };
  # }}}
}
