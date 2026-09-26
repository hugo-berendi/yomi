{
  config,
  pkgs,
  ...
}: let
  colors = config.lib.stylix.colors;
  c = colors.withHashtag;
  rgb = base: "${colors."${base}-rgb-r"}, ${colors."${base}-rgb-g"}, ${colors."${base}-rgb-b"}";

  # Karere is WhatsApp Web in a WebKit view. The GTK chrome around it already
  # follows the stylix gtk target, but the page styles itself and karere has
  # no way to add CSS to it. The patch loads ~/.config/karere/user.css as a
  # WebKit user stylesheet; without the file it does nothing.
  karere = pkgs.karere.overrideAttrs (old: {
    patches = (old.patches or []) ++ [./karere-user-css.patch];
  });
in {
  # {{{ Package
  home.packages = [karere];
  # }}}
  # {{{ WhatsApp colours
  # WhatsApp Web's dark mode is a `.dark` class carrying --WDS-* design
  # tokens; the names below come from its production stylesheet, counted by
  # use. The -RGB twins are "r, g, b" triples the page feeds into rgba(), so
  # they have to move with their colours or translucent overlays keep the
  # old green. Colour roles only -- WhatsApp's class names churn weekly.
  xdg.configFile."karere/user.css".text = ''
    .dark {
      --WDS-app-wash: ${c.base00} !important;
      --WDS-background-wash-plain: ${c.base00} !important;
      --WDS-background-wash-plain-RGB: ${rgb "base00"} !important;
      --WDS-background-wash-inset: ${c.base01} !important;
      --WDS-background-wash-inset-RGB: ${rgb "base01"} !important;
      --WDS-background-elevated-wash-plain: ${c.base01} !important;
      --WDS-background-elevated-wash-inset: ${c.base01} !important;

      --WDS-surface-default: ${c.base00} !important;
      --WDS-surface-default-RGB: ${rgb "base00"} !important;
      --WDS-surface-emphasized: ${c.base01} !important;
      --WDS-surface-emphasized-RGB: ${rgb "base01"} !important;
      --WDS-surface-elevated-default: ${c.base01} !important;
      --WDS-surface-elevated-default-RGB: ${rgb "base01"} !important;
      --WDS-surface-elevated-emphasized: ${c.base02} !important;
      --WDS-surface-highlight: ${c.base02} !important;
      --WDS-surface-highlight-RGB: ${rgb "base02"} !important;
      --WDS-surface-pressed: ${c.base02} !important;

      --WDS-content-default: ${c.base05} !important;
      --WDS-content-default-RGB: ${rgb "base05"} !important;
      --WDS-content-deemphasized: ${c.base04} !important;
      --WDS-content-disabled: ${c.base03} !important;
      --WDS-content-on-accent: ${c.base00} !important;
      --WDS-content-on-accent-RGB: ${rgb "base00"} !important;
      --WDS-content-action-default: ${c.base0D} !important;
      --WDS-content-action-emphasized: ${c.base0D} !important;
      --WDS-content-external-link: ${c.base0C} !important;
      --WDS-content-read: ${c.base0C} !important;

      --WDS-accent: ${c.base0D} !important;
      --WDS-accent-RGB: ${rgb "base0D"} !important;
      --WDS-accent-deemphasized: ${c.base02} !important;
      --WDS-accent-emphasized: ${c.base0E} !important;

      --WDS-systems-bubble-surface-incoming: ${c.base01} !important;
      --WDS-systems-bubble-surface-incoming-RGB: ${rgb "base01"} !important;
      --WDS-systems-bubble-surface-outgoing: ${c.base02} !important;
      --WDS-systems-bubble-surface-outgoing-RGB: ${rgb "base02"} !important;
      --WDS-systems-bubble-surface-overlay: ${c.base01} !important;
      --WDS-systems-bubble-surface-overlay-RGB: ${rgb "base01"} !important;
      --WDS-systems-bubble-content-deemphasized: ${c.base04} !important;
      --WDS-systems-bubble-content-deemphasized-RGB: ${rgb "base04"} !important;
    }
  '';
  # }}}
}
