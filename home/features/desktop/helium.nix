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

  # Initial preferences for the browser (applied on first run)
  initialPrefs = {
    helium = {
      services = {
        enabled = false;
        browser_updates = false;
        bangs = false;
        ext_proxy = false;
        spellcheck_files = false;
        ublock_assets = false;
        user_consented = true;
        origin_override = "";
      };
      completed_onboarding = true;
    };
    distribution = {
      skip_first_run_ui = true;
      suppress_first_run_default_browser_prompt = true;
    };
    # General Privacy
    signin = {
      allowed = false;
    };
    # Disable AI/GenAI features if possible via prefs
    optimization_guide = {
      model_execution_enabled = false;
    };
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
      (lib.genAttrs extensions mkExtensionPolicy)
      // {
        "*" = {
          "installation_mode" = "allowed";
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
    "--initial-preferences-file=${pkgs.writeText "helium-initial-prefs.json" (builtins.toJSON initialPrefs)}"
  ];

  # Wrapper to pass flags
  heliumPackage = pkgs.symlinkJoin {
    name = "helium";
    paths = [inputs.helium.packages.${pkgs.system}.default];
    buildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/helium \
        --add-flags "${lib.concatStringsSep " " flags}"
    '';
  };

  # {{{ External Extensions
  # Write External Extensions JSONs which works reliably on Linux without policies
  # https://developer.chrome.com/docs/extensions/how-to/distribute/install-extensions#linux-preferences
  mkExternalExtFile = id: {
    name = "helium/External Extensions/${id}.json";
    value = {
      text = builtins.toJSON {
        external_update_url = "https://clients2.google.com/service/update2/crx";
      };
    };
  };

  externalExtensions = builtins.listToAttrs (map mkExternalExtFile extensions);
in {
  home.packages = [heliumPackage];

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

  # {{{ Config Files
  # We merge the policy files and the external extensions into one attribute set
  xdg.configFile =
    externalExtensions
    // {
      "chromium/policies/managed/default.json".text = builtins.toJSON policyConfig;
      "helium/policies/managed/default.json".text = builtins.toJSON policyConfig;
    };
  # }}}
}
