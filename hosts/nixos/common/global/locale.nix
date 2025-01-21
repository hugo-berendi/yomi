{
  pkgs,
  lib,
  config,
  ...
}: let
  kb_locale = "de_DE.UTF-8";
in {
  # Set your time zone.
  time.timeZone = "Europe/Berlin";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.supportedLocales =
    lib.unique
    (builtins.map (l: (lib.replaceStrings ["utf8" "utf-8" "UTF8"] ["UTF-8" "UTF-8" "UTF-8"] l) + "/UTF-8") (
      [
        kb_locale
        config.i18n.defaultLocale
      ]
      ++ (lib.attrValues (lib.filterAttrs (n: v: n != "LANGUAGE") config.i18n.extraLocaleSettings))
    ));

  i18n.glibcLocales = pkgs.glibcLocales.override {
    allLocales = false;
    locales = config.i18n.supportedLocales;
  };

  i18n.extraLocaleSettings = {
    LANGUAGE = kb_locale;
    LANG = kb_locale;
    LC_ALL = kb_locale;
    LC_ADDRESS = kb_locale;
    LC_IDENTIFICATION = kb_locale;
    LC_MEASUREMENT = kb_locale;
    LC_MONETARY = kb_locale;
    LC_NAME = kb_locale;
    LC_NUMERIC = kb_locale;
    LC_PAPER = kb_locale;
    LC_TELEPHONE = kb_locale;
    LC_TIME = kb_locale;
  };
}
