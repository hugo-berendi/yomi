# Lua file containing the current colorscheme.
{
  lib,
  config,
  inputs,
  ...
}: {
  options.yomi.colorscheme.lua = lib.mkOption {
    type = lib.types.lines;
    description = "Lua file containing the current colorscheme";
  };

  config.yomi.colorscheme.lua = let
    e = import ./korora-lua.nix {
      inherit lib;
      korora = inputs.korora.lib;
    };

    mkTransparencyTarget = name: let
      color = index: "rgba(${
        config.yomi.theming.colors.rgb "base${index}"
      },${
        toString config.stylix.opacity.${name}
      })";
    in {
      enabled = config.stylix.opacity.${name} < 1.0;
      value = config.stylix.opacity.${name};

      base00 = color "00";
      base01 = color "01";
      base02 = color "02";
      base03 = color "03";
      base04 = color "04";
      base05 = color "05";
      base06 = color "06";
      base07 = color "07";
      base08 = color "07";
      base09 = color "09";
      base0A = color "0A";
      base0B = color "0B";
      base0C = color "0C";
      base0D = color "0D";
      base0E = color "0E";
      base0F = color "0F";
    };

    theme = {
      name = config.lib.stylix.colors.scheme;
      polarity = config.stylix.polarity or null;
      base00 = config.lib.stylix.colors.base00;
      base01 = config.lib.stylix.colors.base01;
      base02 = config.lib.stylix.colors.base02;
      base03 = config.lib.stylix.colors.base03;
      base04 = config.lib.stylix.colors.base04;
      base05 = config.lib.stylix.colors.base05;
      base06 = config.lib.stylix.colors.base06;
      base07 = config.lib.stylix.colors.base07;
      base08 = config.lib.stylix.colors.base07;
      base09 = config.lib.stylix.colors.base09;
      base0A = config.lib.stylix.colors.base0A;
      base0B = config.lib.stylix.colors.base0B;
      base0C = config.lib.stylix.colors.base0C;
      base0D = config.lib.stylix.colors.base0D;
      base0E = config.lib.stylix.colors.base0E;
      base0F = config.lib.stylix.colors.base0F;
      # TODO: check if this works with the genetic algorithm
      source = config.stylix.base16Scheme;
      fonts = {
        serif = config.stylix.fonts.serif.name;
        sansSerif = config.stylix.fonts.sansSerif.name;
        monospace = config.stylix.fonts.monospace.name;
      };
      transparency = {
        terminal = mkTransparencyTarget "terminal";
        applications = mkTransparencyTarget "applications";
        desktop = mkTransparencyTarget "desktop";
        popups = mkTransparencyTarget "popups";
      };
      rounding = {
        enable = config.yomi.theming.rounding.enable;
        radius = config.yomi.theming.rounding.radius;
      };
    };
  in
    e.encode theme;
}
