{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  # {{{ Global extensions
  extensions = with inputs.firefox-addons.packages.${pkgs.system}; [
    buster-captcha-solver
    # REASON: returns 404 for now
    # bypass-paywalls-clean
    clearurls # removes ugly args from urls
    cliget # Generates curl commands for downloading account-protected things
    don-t-fuck-with-paste # disallows certain websites from disabling pasting
    decentraleyes # Serves local copies of a bunch of things instead of reaching a CDN
    gesturefy # mouse gestures
    indie-wiki-buddy # redirects fandom wiki urls to the proper wikis
    i-dont-care-about-cookies
    localcdn # caches libraries locally
    privacy-badger # blocks some trackers
    privacy-pass # captcha stuff
    # privacy-redirect # allows redirecting to my own instances for certain apps
    skip-redirect # attempts to skip to the final reddirect for certain urls
    terms-of-service-didnt-read
    translate-web-pages
    ublock-origin
    unpaywall
    user-agent-string-switcher
    darkreader
  ];
  # }}}
  customUrl = "https://hugo-berendi.github.io/startpage/";
in {
  programs.firefox = {
    enable = true;

    package = pkgs.firefox;

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
      # Unique user id
      id = 0;

      # Make this the default user
      isDefault = true;

      # Forcefully replace the search configuration
      search.force = true;
      search.default = "Startpage";

      # Set styles applied to firefox itself
      userChrome = builtins.readFile ./userChrome.css;
      # userContent = builtins.readFile ./userContent.css;

      # }}}
      # {{{ Extensions
      extensions = with inputs.firefox-addons.packages.${pkgs.system};
      with lib.lists;
        flatten [
          extensions
          # List of profile-specific extensions
          [
            augmented-steam # Adds more info to steam
            proton-pass # Password manager
            blocktube # Lets you block youtube channels
            dearrow # Crowdsourced clickbait remover 💀
            leechblock-ng # website blocker
            lovely-forks # displays forks on github
            octolinker # github import to link thingy
            octotree # github file tree
            refined-github # a bunch of github modifications
            return-youtube-dislikes
            steam-database # adds info from steamdb on storepages
            sponsorblock # skip youtube sponsors
            vimium-c # vim keybinds
            youtube-shorts-block
            libredirect # redirect to FOSS alternatives
          ]
        ];
      # }}}

      # {{{ Search engines
      search.engines = let
        # {{{ Search engine creation helpers
        mkBasicSearchEngine = {
          aliases,
          url,
          param,
          icon ? null,
        }:
          {
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

            definedAliases = aliases;
          }
          // (
            if icon == null
            then {}
            else {inherit icon;}
          );

        mkNixPackagesEngine = {
          aliases,
          type,
        }:
          mkBasicSearchEngine {
            aliases = aliases;
            url = "https://search.nixos.org/${type}";
            param = "query";
            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
          };
        # }}}
        # {{{ Engine declarations
      in {
        "Nix Packages" = mkNixPackagesEngine {
          aliases = ["@np" "@nix-packages"];
          type = "packages";
        };

        "Nix Options" = mkNixPackagesEngine {
          aliases = ["@no" "@nix-options"];
          type = "options";
        };

        "Home-Manager Options" = mkBasicSearchEngine {
          url = "https://home-manager-options.extranix.com/";
          param = "query";
          aliases = ["@hmo" "@home-manager-options"];
          icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
        };

        "Wikipedia" = mkBasicSearchEngine {
          url = "https://en.wikipedia.org/wiki/Special:Search";
          param = "search";
          aliases = ["@wk" "@wikipedia"];
        };

        "Github" = mkBasicSearchEngine {
          url = "https://github.com/search";
          param = "q";
          aliases = ["@gh" "@github"];
        };

        "Startpage" = mkBasicSearchEngine {
          url = "https://www.startpage.com/sp/search";
          param = "query";
          aliases = ["@sp" "@startpage"];
        };

        "Warframe Wiki" = mkBasicSearchEngine {
          url = "https://warframe.fandom.com/wiki/Special:Search";
          param = "query";
          aliases = ["@wf" "@warframe-wiki"];
        };
      };
      # }}}
      # }}}
      # {{{ Other lower level settings
      settings = {
        # Required for figma to be able to export to svg
        "dom.events.asyncClipboard.clipboardItem" = true;

        # Allow custom css
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;

        # Set language to english
        "general.useragent.locale" = "en-US";

        # Do not restore sessions after what looks like a "crash"
        "browser.sessionstore.resume_from_crash" = false;

        # Do not paste with middle mouse click
        "middlemouse.paste" = false;

        # Inspired by https://github.com/TLATER/dotfiles/blob/b39af91fbd13d338559a05d69f56c5a97f8c905d/home-config/config/graphical-applications/firefox.nix
        # {{{ Performance settings
        "gfx.webrender.all" = true; # Force enable GPU acceleration
        "media.ffmpeg.vaapi.enabled" = true;
        "widget.dmabuf.force-enabled" = true; # Required in recent Firefoxes
        # }}}
        "browser.startup.homepage" = "${customUrl}";
        # {{{ New tab page
        "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons" =
          false;
        "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features" =
          false;
        "browser.newtabpage.activity-stream.feeds.snippets" = false;
        "browser.newtabpage.activity-stream.improvesearch.topSiteSearchShortcuts.havePinned" = "";
        "browser.newtabpage.activity-stream.improvesearch.topSiteSearchShortcuts.searchEngines" = "";
        "browser.newtabpage.activity-stream.section.highlights.includePocket" =
          false;
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

        # Keep the reader button enabled at all times; really don't
        # care if it doesn't work 20% of the time, most websites are
        # crap and unreadable without this
        "reader.parse-on-load.force-enabled" = true;

        # Hide the "sharing indicator", it's especially annoying
        # with tiling WMs on wayland
        "privacy.webrtc.legacyGlobalIndicator" = false;

        # Do not include "switch to [tab]" in search results
        "browser.urlbar.suggest.openpage" = false;

        # Hide random popup: https://forums.linuxmint.com/viewtopic.php?t=379164
        "browser.protections_panel.infoMessage.seen" = true;

        # Disable shortcut for quitting :)
        "browser.quitShortcut.disabled" = true;

        # Do not show dialog for getting panes in the addons menu (?)
        # http://kb.mozillazine.org/Extensions.getAddons.showPane
        "extensions.getAddons.showPane" = false;

        # Do not recommend addons
        "extensions.htmlaboutaddons.recommendations.enabled" = false;

        # auto-enable all extensions
        "extensions.autoDisableScopes" = 0;
      };
      # }}}
    };

    # {{{ Standalone "apps" which actually run inside a browser.
    apps.extensions = extensions;
    apps.app = {
      # TODO: auto increment ids
      # {{{ Desmos
      desmos = {
        url = "https://www.desmos.com/calculator";
        icon = ../../../../common/icons/desmos.png;
        displayName = "Desmos";
        id = 1;
      };
      # }}}
      # {{{ Monkey type
      monkey-type = {
        url = "https://monkeytype.com/";
        icon = ../../../../common/icons/monkeytype.png;
        displayName = "Monkeytype";
        id = 2;
      };
      # }}}
      # {{{ Clockify
      clockify = {
        url = "https://app.clockify.me/";
        icon = ../../../../common/icons/clockify.png;
        displayName = "Clockify";
        id = 3;
      };
      # }}}
      #{{{ Proton Mail
      proton-mail = {
        url = "https://mail.protonmail.com/";
        icon = ../../../../common/icons/protonmail.png;
        displayName = "Proton Mail";
        id = 4;
      };
      #}}}
      # {{{ Proton Drive
      proton-drive = {
        url = "https://drive.protonmail.com/";
        icon = ../../../../common/icons/protondrive.png;
        displayName = "Proton Drive";
        id = 5;
      };
      # }}}
    };
    # }}}
  };

  # {{{ Make firefox the default
  # Use firefox as the default browser to open stuff.
  xdg.mimeApps.defaultApplications = {
    "text/html" = ["firefox.desktop"];
    "text/xml" = ["firefox.desktop"];
    "x-scheme-handler/http" = ["firefox.desktop"];
    "x-scheme-handler/https" = ["firefox.desktop"];
  };

  # Tell apps firefox is the default browser using an env var.
  home.sessionVariables.BROWSER = "firefox";
  # }}}

  # {{{ Persistence
  satellite.persistence.at.state.apps.firefox.directories = [
    ".mozilla/firefox" # More important stuff
  ];

  satellite.persistence.at.cache.apps.firefox.directories = [
    "${config.xdg.cacheHome}/mozilla/firefox" # Non important cache
  ];
  # }}}
}
