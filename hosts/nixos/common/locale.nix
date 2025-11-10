{
  config,
  lib,
  ...
}: let
  lang = config.i18n.defaultLocale;
in {
  # {{{ Time zone
  time.timeZone = "Europe/Berlin";
  # }}}
  # {{{ Locale
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LANGUAGE = lang;
    LANG = lang;
    LC_ALL = lang;
    LC_ADDRESS = lang;
    LC_IDENTIFICATION = lang;
    LC_MEASUREMENT = lang;
    LC_MONETARY = lang;
    LC_NAME = lang;
    LC_NUMERIC = lang;
    LC_PAPER = lang;
    LC_TELEPHONE = lang;
    LC_TIME = lang;
  };
  # }}}
  # {{{ Console keymap
  console.keyMap = lib.mkForce "de";
  # }}}
}
