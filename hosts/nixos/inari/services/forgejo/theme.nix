{
  config,
  pkgs,
  lib,
  ...
}: let
  themeName = "yomi";
  themeFile = pkgs.writeText "theme-${themeName}.css" (
    with config.lib.stylix.colors.withHashtag; let
      dark = config.stylix.polarity == "dark";
      baseTheme =
        if dark
        then "dark"
        else "light";
      colorScheme =
        if dark
        then "dark"
        else "light";
    in ''
      @import "./theme-forgejo-${baseTheme}.css";

      :root {
        --color-primary: ${base0D};
        --color-primary-hover: ${base0C};
        --color-primary-active: ${base0E};
        --color-primary-alpha-10: ${base0D}1a;
        --color-primary-alpha-20: ${base0D}33;
        --color-primary-alpha-30: ${base0D}4d;
        --color-primary-alpha-40: ${base0D}66;
        --color-primary-alpha-50: ${base0D}80;
        --color-primary-alpha-60: ${base0D}99;
        --color-primary-alpha-70: ${base0D}b3;
        --color-primary-alpha-80: ${base0D}cc;
        --color-primary-alpha-90: ${base0D}e6;
        --color-secondary: ${base01};
        --color-secondary-hover: ${base02};
        --color-secondary-active: ${base03};
        --color-body: ${base00};
        --color-box-header: ${base01};
        --color-box-body: ${base01};
        --color-box-body-highlight: ${base02};
        --color-text: ${base05};
        --color-text-light: ${base04};
        --color-text-light-1: ${base04};
        --color-text-light-2: ${base03};
        --color-text-light-3: ${base03};
        --color-footer: ${base00};
        --color-timeline: ${base03};
        --color-input-text: ${base05};
        --color-input-background: ${base01};
        --color-input-toggle-background: ${base01};
        --color-input-border: ${base03};
        --color-input-border-hover: ${base04};
        --color-header-wrapper: ${base00};
        --color-hover: ${base02};
        --color-active: ${base03};
        --color-menu: ${base01};
        --color-card: ${base01};
        --color-markup-code-block: ${base01};
        --color-markup-code-inline: ${base01};
        --color-button: ${base02};
        --color-code-bg: ${base01};
        --color-secondary-bg: ${base01};
        --color-nav-bg: ${base00};
        --color-nav-hover-bg: ${base02};
        --color-nav-text: ${base05};
        --color-secondary-nav-bg: ${base00};
        --color-accent: ${base0D};
        --color-small-accent: ${base0C};
        --color-highlight-fg: ${base0D};
        --color-highlight-bg: ${base02};
        --color-reaction-active-bg: ${base0D}33;
        --color-reaction-hover-bg: ${base0D}4d;
        --color-label-text: ${base05};
        --color-label-bg: ${base02};
        --color-label-hover-bg: ${base03};
        --color-label-active-bg: ${base04};
        --color-label-bg-alt: ${base03};
        --color-red: ${base08};
        --color-orange: ${base09};
        --color-yellow: ${base0A};
        --color-green: ${base0B};
        --color-teal: ${base0C};
        --color-blue: ${base0D};
        --color-violet: ${base0E};
        --color-purple: ${base0E};
        --color-brown: ${base0F};
        accent-color: ${base0D};
        color-scheme: ${colorScheme};
      }

      body,
      button,
      input,
      select,
      textarea {
        font-family: "${config.stylix.fonts.sansSerif.name}", sans-serif;
      }

      code,
      pre,
      .monospace {
        font-family: "${config.stylix.fonts.monospace.name}", monospace;
      }
    ''
  );
in {
  services.forgejo.settings.ui = {
    DEFAULT_THEME = themeName;
    THEMES = lib.strings.concatStringsSep "," [
      "forgejo-auto"
      "forgejo-light"
      "forgejo-dark"
      themeName
    ];
  };

  systemd.tmpfiles.rules = [
    "d ${config.services.forgejo.customDir}/public - ${config.services.forgejo.user} ${config.services.forgejo.group} -"
    "d ${config.services.forgejo.customDir}/public/assets - ${config.services.forgejo.user} ${config.services.forgejo.group} -"
    "d ${config.services.forgejo.customDir}/public/assets/css - ${config.services.forgejo.user} ${config.services.forgejo.group} -"
    "L+ ${config.services.forgejo.customDir}/public/assets/css/theme-${themeName}.css - ${config.services.forgejo.user} ${config.services.forgejo.group} - ${themeFile}"
  ];
}
