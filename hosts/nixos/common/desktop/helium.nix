{
  config,
  lib,
  ...
}: let
  engines = lib.importTOML ../../../../home/features/desktop/browser/engines.toml;
  siteSearch = lib.concatMap (
    name:
      map (shortcut: {
        inherit shortcut;
        name =
          if shortcut == builtins.head engines.${name}.aliases
          then name
          else "${name} (${shortcut})";
        url = "${engines.${name}.url}?${engines.${name}.param}={searchTerms}";
      })
      engines.${name}.aliases
  ) (builtins.attrNames engines);
  extensionUpdateUrl = "https://services.helium.imput.net/ext/";
  extensions = import ../../../../home/features/desktop/browser/extensions.nix;
  initialPreferences.extensions.theme.system_theme = 0;
  policies = {
    AlwaysOpenPdfExternally = true;
    AutofillAddressEnabled = false;
    AutofillCreditCardEnabled = false;
    BackgroundModeEnabled = false;
    BrowserSignin = 0;
    BlockThirdPartyCookies = true;
    BookmarkBarEnabled = false;
    DefaultBrowserSettingEnabled = false;
    DefaultSearchProviderEnabled = true;
    DefaultSearchProviderKeyword = "startpage.com";
    DefaultSearchProviderName = "Startpage";
    DefaultSearchProviderSearchURL = "https://www.startpage.com/sp/search?query={searchTerms}&cat=web&pl=chrome";
    Disable3DAPIs = false;
    ExtensionInstallForcelist = map (id: "${id};${extensionUpdateUrl}") extensions;
    HomepageIsNewTabPage = false;
    HomepageLocation = "https://lab.hugo-berendi.de";
    HttpsOnlyMode = "force_enabled";
    MetricsReportingEnabled = false;
    NetworkPredictionOptions = 2;
    PasswordManagerEnabled = false;
    RestoreOnStartup = 1;
    SafeBrowsingProtectionLevel = 1;
    SearchSuggestEnabled = false;
    SiteSearchSettings = siteSearch;
    SpellcheckEnabled = true;
    SpellcheckLanguage = ["en-US"];
    SyncDisabled = true;
    TranslateEnabled = true;
  };
in
  lib.mkIf config.yomi.machine.graphical {
    environment.etc."chromium/initial_preferences".text = builtins.toJSON initialPreferences;
    environment.etc."helium/initial_preferences".text = builtins.toJSON initialPreferences;
    environment.etc."chromium/policies/managed/helium-yomi.json".text = builtins.toJSON policies;
    environment.etc."helium/policies/managed/helium-yomi.json".text = builtins.toJSON policies;
  }
