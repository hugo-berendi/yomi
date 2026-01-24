{
  pkgs,
  lib,
  config,
  inputs,
  ...
}: let
  engines = lib.importTOML ./firefox/engines.toml;

  # Helper to convert engines.toml format to Chromium SiteSearchSettings
  mkChromiumSearch = name: data: {
    name = name;
    shortcut = builtins.head data.aliases;
    url = "${data.url}?${data.param}={searchTerms}";
  };

  # Extract SearxNG for the default provider configuration
  searxng = engines."searxng";
  defaultSearchURL = "${searxng.url}?${searxng.param}={searchTerms}";

  extensions = [
    "cjpalhdlnbpafiamejdnhcphjbkeiagm" # uBlock Origin
    "nngceckbapebfimnlniiiahkandclblb" # Bitwarden
    "lckanjgmijmafbedplaimeclbjfcpbdk" # ClearURLs
    "njdfdhgchcpfjjberbghaegflmagbdoo" # LocalCDN
    "ajhmfdgkijocedmfjonnpjfojldioehi" # Privacy Pass
    "hjdoplcnndgiblooccencgcggcoedceo" # Terms of Service; Didn't Read
    "iplffkdpngmdjhlpjmppncnlhomiipha" # Unpaywall
    "hfjbmagddngcpeloejdejnfgbamkjaeg" # Vimium C
    "eimadpbcbfnmbkopoojfekhnkhdbieeh" # Dark Reader
    "bhchdcejhohfmigjdonfgnilgcjgocgl" # User-Agent Switcher and Manager
    "hlepfoohegkhhmjieoechaddaejaokhf" # Refined GitHub
    "dnhpnfgdlenaccegplpojghhmaamnnfp" # Augmented Steam
    "fkagelmloambgokoeokbpihmgpkbgbfm" # Indie Wiki Buddy
    "bbeicapbemckcnkmnppddgpljaaicpbe" # BlockTube
    "gebbhagfogifgggkldgodflihgfeippi" # Return YouTube Dislike
    "jiaopdjbehhjgokpphdfgmapkobbnmjp" # YouTube Shorts Block
    "nipdbleimjhfpfdkopbfeagjjkmcfhbj" # Mouse Gesture (Replacement for Gesturefy)
    "ohjebgkppidheiajbgnnmmieaapjppje" # Rose Pine Moon Theme
  ];

  # Helper to create extension settings policy
  mkExtensionPolicy = id: {
    installation_mode = "force_installed";
    update_url = "https://clients2.google.com/service/update2/crx";
  };

  policyConfig = {
    # Privacy & Telemetry
    "SigninAllowed" = false;
    "SyncDisabled" = true;
    "PasswordManagerEnabled" = false;
    "BrowserSignin" = 0;
    "MetricsReportingEnabled" = false;
    "SpellcheckEnabled" = false;
    "OptimizationGuideMeasuresEnabled" = false;
    "ComponentUpdatesEnabled" = false;
    "ChromeCleanerEnabled" = false;
    "ReportDeviceCrashReports" = false;

    # AI & Generative Features
    "GenAiDefaultSettings" = 2; # 2 = Disabled
    "HelpMeWriteEnabled" = false;
    "TabOrganizerSettings" = 2; # 2 = Disabled
    "CreateThemesSettings" = 2; # 2 = Disabled
    "DevToolsGenAiSettings" = 2; # 2 = Disabled
    "ContextualSearchEnabled" = false;

    # Search Engine
    "DefaultSearchProviderEnabled" = true;
    "DefaultSearchProviderName" = "SearxNG";
    "DefaultSearchProviderKeyword" = "@s";
    "DefaultSearchProviderSearchURL" = defaultSearchURL;
    "DefaultSearchProviderIconURL" = searxng.icon;
    
    # Helium Specific Settings
    "helium.services.enabled" = false;
    "helium.services.browser_updates" = false;
    
    # Map other engines from engines.toml
    "SiteSearchSettings" = 
      lib.attrsets.mapAttrsToList mkChromiumSearch engines;

    # Extension Settings
    "ExtensionSettings" = 
      (lib.genAttrs extensions mkExtensionPolicy) // {
        "*" = {
          "installation_mode" = "allowed";
        };
        # Pin uBlock Origin
        "cjpalhdlnbpafiamejdnhcphjbkeiagm" = {
          "toolbar_pin" = "force_pinned";
          "installation_mode" = "force_installed";
          "update_url" = "https://clients2.google.com/service/update2/crx";
        };
      };
  };

  flags = [
    "--disable-features=PreloadMediaEngagementData,MediaEngagementBypassAutoplayPolicies"
    "--disable-reading-from-canvas"
    "--no-pings"
    "--no-first-run"
    "--no-default-browser-check"
    "--disable-breakpad"
    "--disable-sync"
    "--disable-speech-api"
    "--disable-wake-on-wifi"
  ];

  # Wrapper to pass flags
  heliumPackage = pkgs.symlinkJoin {
    name = "helium";
    paths = [ inputs.helium.packages.${pkgs.system}.default ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/helium \
        --add-flags "${lib.concatStringsSep " " flags}"
    '';
  };

in {
  home.packages = [ heliumPackage ];

  # {{{ Desktop Entry
  # Override desktop entry to pass flags (since we are not using programs.chromium)
  xdg.desktopEntries.helium = {
    name = "Helium";
    genericName = "Web Browser";
    exec = "helium %U";
    terminal = false;
    icon = "helium";
    type = "Application";
    categories = ["Network" "WebBrowser"];
    mimeType = ["text/html" "text/xml" "x-scheme-handler/http" "x-scheme-handler/https"];
  };
  # }}}

  # {{{ Default Browser
  xdg.mimeApps.defaultApplications = {
    "text/html" = ["helium.desktop"];
    "text/xml" = ["helium.desktop"];
    "x-scheme-handler/http" = ["helium.desktop"];
    "x-scheme-handler/https" = ["helium.desktop"];
  };

  home.sessionVariables.BROWSER = "helium";
  # }}}

  # {{{ Policies
  # Write to both chromium and helium config dirs to ensure policies are picked up
  xdg.configFile."chromium/policies/managed/default.json".text = builtins.toJSON policyConfig;
  xdg.configFile."helium/policies/managed/default.json".text = builtins.toJSON policyConfig;
  # }}}
}
