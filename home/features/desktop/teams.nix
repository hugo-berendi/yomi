{
  config,
  pkgs,
  ...
}: let
  c = config.lib.stylix.colors.withHashtag;

  # Teams v2 is Fluent UI 9. Every colour is a custom property that a
  # FluentProvider sets through a generated class, so an !important
  # declaration on the provider outranks it for everything underneath.
  # Only colour roles are touched; layout is Microsoft's to change, and a
  # stylesheet that restyles markup breaks with every Teams release.
  css = pkgs.writeText "teams-stylix.css" ''
    .fui-FluentProvider, :root {
      --colorNeutralBackground1: ${c.base00} !important;
      --colorNeutralBackground1Hover: ${c.base01} !important;
      --colorNeutralBackground1Pressed: ${c.base02} !important;
      --colorNeutralBackground1Selected: ${c.base02} !important;
      --colorNeutralBackground2: ${c.base01} !important;
      --colorNeutralBackground2Hover: ${c.base02} !important;
      --colorNeutralBackground2Pressed: ${c.base02} !important;
      --colorNeutralBackground2Selected: ${c.base02} !important;
      --colorNeutralBackground3: ${c.base01} !important;
      --colorNeutralBackground3Hover: ${c.base02} !important;
      --colorNeutralBackground3Pressed: ${c.base02} !important;
      --colorNeutralBackground3Selected: ${c.base02} !important;
      --colorNeutralBackground4: ${c.base00} !important;
      --colorNeutralBackground5: ${c.base00} !important;
      --colorNeutralBackground6: ${c.base01} !important;
      --colorNeutralCardBackground: ${c.base01} !important;
      --colorNeutralCardBackgroundHover: ${c.base02} !important;
      --colorSubtleBackgroundHover: ${c.base02} !important;
      --colorSubtleBackgroundPressed: ${c.base02} !important;
      --colorSubtleBackgroundSelected: ${c.base02} !important;

      --colorNeutralForeground1: ${c.base05} !important;
      --colorNeutralForeground1Hover: ${c.base05} !important;
      --colorNeutralForeground2: ${c.base05} !important;
      --colorNeutralForeground2Hover: ${c.base05} !important;
      --colorNeutralForeground3: ${c.base04} !important;
      --colorNeutralForeground4: ${c.base03} !important;
      --colorNeutralForegroundDisabled: ${c.base03} !important;

      --colorNeutralStroke1: ${c.base02} !important;
      --colorNeutralStroke2: ${c.base02} !important;
      --colorNeutralStroke3: ${c.base01} !important;

      --colorBrandBackground: ${c.base0D} !important;
      --colorBrandBackgroundHover: ${c.base0E} !important;
      --colorBrandBackgroundPressed: ${c.base0E} !important;
      --colorBrandForeground1: ${c.base0D} !important;
      --colorBrandForeground2: ${c.base0D} !important;
      --colorBrandForegroundLink: ${c.base0C} !important;
      --colorBrandStroke1: ${c.base0D} !important;
      --colorCompoundBrandForeground1: ${c.base0D} !important;
      --colorCompoundBrandBackground: ${c.base0D} !important;
      --colorNeutralForegroundOnBrand: ${c.base00} !important;

      --colorPaletteRedForeground1: ${c.base08} !important;
      --colorPaletteRedBackground3: ${c.base08} !important;
      --colorPaletteGreenForeground1: ${c.base0B} !important;
      --colorPaletteYellowForeground1: ${c.base0A} !important;
    }
  '';
in {
  home.packages = [pkgs.teams-for-linux];

  # A store symlink is fine: teams-for-linux only require()s this file, and
  # keeps what it changes at runtime in settings.json beside it.
  #
  # followSystemTheme makes Teams pick its own dark theme from the portal's
  # color-scheme; the stylesheet then recolours that dark theme.
  xdg.configFile."teams-for-linux/config.json".text = builtins.toJSON {
    followSystemTheme = true;
    customCSSLocation = "${css}";
  };
}
