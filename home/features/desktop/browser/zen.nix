{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  # {{{ Imports
  imports = [
    inputs.zen-browser.homeModules.twilight
  ];
  # }}}
  # {{{ Programs
  programs.zen-browser = {
    enable = true;

    policies = {
      DisableAppUpdate = true;
      DisableBuiltinPDFViewer = true;
      DisableFirefoxAccounts = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DisableTelemetry = true;
      DisplayBookmarksToolbar = "never";
      DontCheckDefaultBrowser = true;
      EnableTrackingProtection = {
        Value = true;
        Locked = true;
        Cryptomining = true;
        Fingerprinting = true;
      };
      OfferToSaveLogins = false;
      PasswordManagerEnabled = false;
    };

    profiles.${config.home.username} = {
      # {{{ High level user settings
      id = 0;
      isDefault = true;
      search.force = true;
      search.default = "searxng";
      # }}}
      # {{{ Extensions
      extensions = {
        packages = with inputs.firefox-addons.packages.${pkgs.system};
        with lib.lists;
          flatten [
            [
              addy_io
              augmented-steam
              blocktube
              bitwarden
              darkreader
              dearrow
              don-t-fuck-with-paste
              gesturefy
              indie-wiki-buddy
              leechblock-ng
              libredirect
              localcdn
              octolinker
              privacy-pass
              refined-github
              return-youtube-dislikes
              sponsorblock
              steam-database
              terms-of-service-didnt-read
              ublock-origin
              unpaywall
              user-agent-string-switcher
              vimium-c
              karakeep
            ]
          ];
      };
      # }}}
      # {{{ Search engines
      search.engines = let
        mkBasicSearchEngine = {
          aliases,
          url,
          param,
          icon,
        }: {
          inherit icon;
          definedAliases = aliases;
          urls = [
            {
              template = url;
              params = [
                {
                  name = param;
                  value = "{searchTerms}";
                }
              ];
            }
          ];
        };
      in
        {
          google.metaData.alias = "@g";
        }
        // lib.attrsets.mapAttrs (_: mkBasicSearchEngine) (lib.importTOML ./engines.toml);
      # }}}
      # {{{ Settings
      settings = {
        "dom.events.asyncClipboard.clipboardItem" = true;
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        "general.useragent.locale" = "en-US";
        "browser.sessionstore.resume_from_crash" = false;
        "middlemouse.paste" = false;
        "browser.urlbar.suggest.openpage" = false;
        "browser.quitShortcut.disabled" = true;
        # {{{ Performance settings
        "gfx.webrender.all" = true;
        "media.ffmpeg.vaapi.enabled" = true;
        "widget.dmabuf.force-enabled" = true;
        # }}}
        "browser.startup.homepage" = "https://lab.hugo-berendi.de";
        # {{{ New tab page
        "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons" = false;
        "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features" = false;
        "browser.newtabpage.activity-stream.feeds.snippets" = false;
        "browser.newtabpage.activity-stream.improvesearch.topSiteSearchShortcuts.havePinned" = "";
        "browser.newtabpage.activity-stream.improvesearch.topSiteSearchShortcuts.searchEngines" = "";
        "browser.newtabpage.activity-stream.section.highlights.includePocket" = false;
        "browser.newtabpage.activity-stream.showSponsored" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "browser.newtabpage.pinned" = false;
        # }}}
        # {{{ Privacy
        "browser.contentblocking.category" = "strict";
        "app.shield.optoutstudies.enabled" = false;
        "dom.security.https_only_mode" = true;
        "dom.security.https_only_mode_ever_enabled" = true;
        "datareporting.policy.dataSubmissionEnable" = false;
        "datareporting.policy.dataSubmissionPolicyAcceptedVersion" = 2;
        "privacy.trackingprotection.enabled" = true;
        "privacy.trackingprotection.socialtracking.enabled" = true;
        "browser.discovery.enabled" = false;
        # }}}
        "reader.parse-on-load.force-enabled" = true;
        "privacy.webrtc.legacyGlobalIndicator" = false;
        "browser.protections_panel.infoMessage.seen" = true;
        "extensions.getAddons.showPane" = false;
        "extensions.htmlaboutaddons.recommendations.enabled" = false;
        "extensions.autoDisableScopes" = 0;
      };
      # }}}
    };
  };
  # }}}
  # {{{ Stylix
  stylix.targets.zen-browser = {
    enable = true;
    profileNames = [config.home.username];
  };
  # }}}
  # {{{ Default browser
  xdg.mimeApps.defaultApplications = {
    "text/html" = ["zen.desktop"];
    "text/xml" = ["zen.desktop"];
    "x-scheme-handler/http" = ["zen.desktop"];
    "x-scheme-handler/https" = ["zen.desktop"];
  };

  home.sessionVariables.BROWSER = "zen";
  # }}}
  # {{{ Persistence
  yomi.persistence.at.state.apps.zen-browser.directories = [
    ".zen"
  ];

  yomi.persistence.at.cache.apps.zen-browser.directories = [
    "${config.xdg.cacheHome}/zen"
  ];
  # }}}
}
