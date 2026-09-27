{
  config,
  lib,
  pkgs,
  ...
}: let
  colors = config.lib.stylix.colors;
  c = colors.withHashtag;
  rgba = slot: alpha: "rgba(${colors."${slot}-rgb-r"}, ${colors."${slot}-rgb-g"}, ${colors."${slot}-rgb-b"}, ${toString alpha})";

  # Every colour token Teams defines, read from the live app and assigned a
  # base16 slot by capture-tokens.mjs (which explains how). A handful of
  # hand-written tokens covered only part of the window: the chat list sits
  # on colorNeutralBackground7Hover and colorDefaultBackground7, Teams
  # extensions Fluent does not have, and stayed grey.
  captured = lib.mapAttrs (_: v:
    if builtins.isString v
    then c.${v}
    else rgba v.slot v.alpha) (lib.importJSON ./tokens.json);

  # Choices the lightness mapping cannot make. Text on the accent has to
  # be dark, because this scheme's accent is light; links get their own
  # colour so they read as links inside a message.
  chosen = {
    "--colorNeutralForegroundOnBrand" = c.base00;
    "--colorNeutralForegroundInverted" = c.base00;
    "--colorBrandForegroundLink" = c.base0C;
    "--colorBrandForegroundLinkHover" = c.base0C;
    "--colorBrandForegroundLinkPressed" = c.base0C;
    "--colorBrandForegroundLinkSelected" = c.base0C;
  };

  # Teams v2 is Fluent UI 9, and a FluentProvider sets every token through a
  # generated class, so !important on the provider outranks it for
  # everything underneath. Colour tokens only; layout is Microsoft's to
  # change, and a stylesheet that restyles markup breaks with every release.
  css = pkgs.writeText "teams-stylix.css" ''
    .fui-FluentProvider, :root {
    ${lib.concatStrings (lib.mapAttrsToList (name: value: "  ${name}: ${value} !important;\n") (captured // chosen))}}
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
