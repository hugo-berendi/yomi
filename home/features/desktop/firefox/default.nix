{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  programs.zen = {
    enable = true;

    package = pkgs.zen-browser-bin;

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
      search.default = "searxng";

      # Set styles applied to firefox itself
      # userChrome = builtins.readFile ./userChrome.css;
      # userContent = builtins.readFile ./userContent.css;

      # }}}
      # {{{ Extensions
      extensions = {
        settings = {
        };
        packages = with inputs.firefox-addons.packages.${pkgs.system};
        with lib.lists;
          flatten [
            [
              augmented-steam # Adds more info to steam
              blocktube # Lets you block youtube channels
              bitwarden # password manager
              buster-captcha-solver
              clearurls # removes ugly args from urls
              cliget # Generates curl commands for downloading account-protected things
              darkreader
              dearrow # Crowdsourced clickbait remover 💀
              decentraleyes # Serves local copies of a bunch of things instead of reaching a CDN
              don-t-fuck-with-paste # disallows certain websites from disabling pasting
              gesturefy # mouse gestures
              i-dont-care-about-cookies
              indie-wiki-buddy # redirects fandom wiki urls to the proper wikis
              leechblock-ng # website blocker
              localcdn # caches libraries locally
              octolinker # github import to link thingy
              privacy-badger # blocks some trackers
              privacy-pass # captcha stuff
              privacy-redirect # allows redirecting to my own instances for certain websites
              refined-github # a bunch of github modifications
              return-youtube-dislikes
              sponsorblock # skip youtube sponsors
              skip-redirect # attempts to skip to the final reddirect for certain urls
              steam-database # adds info from steamdb on storepages
              terms-of-service-didnt-read
              translate-web-pages
              ublock-origin
              unpaywall
              user-agent-string-switcher
              vimium-c # vim keybinds
              youtube-shorts-block
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

        # Do not include "switch to [tab]" in search results
        "browser.urlbar.suggest.openpage" = false;

        # Disable shortcut for quitting :)
        "browser.quitShortcut.disabled" = true;

        # Inspired by https://github.com/TLATER/dotfiles/blob/b39af91fbd13d338559a05d69f56c5a97f8c905d/home-config/config/graphical-applications/firefox.nix
        # {{{ Performance settings
        "gfx.webrender.all" = true; # Force enable GPU acceleration
        "media.ffmpeg.vaapi.enabled" = true;
        "widget.dmabuf.force-enabled" = true; # Required in recent Firefoxes
        # }}}
        "browser.startup.homepage" = "https://lab.hugo-berendi.de";
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

        # Hide random popup: https://forums.linuxmint.com/viewtopic.php?t=379164
        "browser.protections_panel.infoMessage.seen" = true;

        # Do not show dialog for getting panes in the addons menu (?)
        # http://kb.mozillazine.org/Extensions.getAddons.showPane
        "extensions.getAddons.showPane" = false;

        # Do not recommend addons
        "extensions.htmlaboutaddons.recommendations.enabled" = false;

        # auto-enable all extensions
        "extensions.autoDisableScopes" = 0;

        "user.theme.dark.base16" = true;

        "ultima.sidebar.autohide" = true;
      };
      # }}}
    };

    # {{{ Standalone "apps" which actually run inside a browser.
    # apps.extensions = extensions;
    # apps.app = {
    #   # TODO: auto increment ids
    #   # {{{ Desmos
    #   desmos = {
    #     url = "https://www.desmos.com/calculator";
    #     icon = ../../../../common/icons/desmos.png;
    #     displayName = "Desmos";
    #     id = 1;
    #   };
    #   # }}}
    #   # {{{ Monkey type
    #   monkey-type = {
    #     url = "https://monkeytype.com/";
    #     icon = ../../../../common/icons/monkeytype.png;
    #     displayName = "Monkeytype";
    #     id = 2;
    #   };
    #   # }}}
    #   # {{{ Clockify
    #   clockify = {
    #     url = "https://app.clockify.me/";
    #     icon = ../../../../common/icons/clockify.png;
    #     displayName = "Clockify";
    #     id = 3;
    #   };
    #   # }}}
    #   #{{{ Proton Mail
    #   proton-mail = {
    #     url = "https://mail.protonmail.com/";
    #     icon = ../../../../common/icons/protonmail.png;
    #     displayName = "Proton Mail";
    #     id = 4;
    #   };
    #   #}}}
    #   # {{{ Proton Drive
    #   proton-drive = {
    #     url = "https://drive.protonmail.com/";
    #     icon = ../../../../common/icons/protondrive.png;
    #     displayName = "Proton Drive";
    #     id = 5;
    #   };
    #   # }}}
    #   # {{{ Excalidraw
    #   excalidraw = {
    #     url = "https://excalidraw.com/";
    #     icon = ../../../../common/icons/excalidraw.png;
    #     displayName = "Excalidraw";
    #     id = 6;
    #   };
    #   # }}}
    #   # {{{ Syncthing
    #   syncthing = {
    #     url = "http://127.0.0.1:8384/";
    #     icon = ../../../../common/icons/syncthing.png;
    #     displayName = "Syncthing";
    #     id = 7;
    #   };
    #   # }}}
    # };
    # }}}
  };

  # Copy FF-ULTIMA files to the chrome folder
  home.file = {
    # ".mozilla/firefox/${config.home.username}/chrome/userChrome.css" = {
    #   source = "${ffUltimaRepo}/userChrome.css";
    # };
    # ".mozilla/firefox/${config.home.username}/chrome/userContent.css" = {
    #   source = "${ffUltimaRepo}/userContent.css";
    # };
    # ".mozilla/firefox/${config.home.username}/chrome/theme" = {
    #   source = "${ffUltimaRepo}/theme";
    #   recursive = true;
    # };
    base16Theme = {
      target = ".mozilla/firefox/${config.home.username}/chrome/theme/all-global-theme-base16.css";
      text =
        /*
        css
        */
        ''
          /*---------------------------- Dark Mode Global Variables -----------------------------
          - Global variables used for ease of modification, and future customization

          [Index] ctrl+f a line to find the specified section:
          Establishing custom variables
          Overwriting existing variables
          Applying variables to create the Dark Mode theme
          Adapting to add-on-theme styling
          Global styling - applies everywhere
          Global styling - Icons
          -------------------------------------------------------------------------------------*/


          @media (prefers-color-scheme: dark) {

          /* Establishing custom variables - allowing most(/all) customization to be done in one place. */

          :root, body, * {
            color-scheme: dark !important; /*--<--dont touch--*/
            --uc-ultima-window: ${config.yomi.theming.colors.rgba "base00"};
            --uc-dark-color: ${config.yomi.theming.colors.rgba "base01"};
            --uc-light-color: ${config.yomi.theming.colors.rgba "base05"};
            --uc-accent-i: ${config.yomi.theming.colors.rgba "base0D"}; /*purp*/
            --uc-accent-ii: ${config.yomi.theming.colors.rgba "base0C"}; /*blue*/
            --uc-accent-iii: ${config.yomi.theming.colors.rgba "base05"}; /*light*/
            --uc-accent-iv: ${config.yomi.theming.colors.rgba "base01"}; /*dark*/
            --uc-accent-v: ${config.yomi.theming.colors.rgba "base0B"}; /*green*/
            --uc-accent-vi: ${config.yomi.theming.colors.rgba "base08"}; /*red*/
            --uc-accent-vii: ${config.yomi.theming.colors.rgba "base02"}; /*darker blue*/
            --uc-background-main: ${config.yomi.theming.colors.rgba "base00"};
            --uc-background-panel: ${config.yomi.theming.colors.rgba "base01"};
            --uc-background-solid: ${config.yomi.theming.colors.rgba "base01"};
            --uc-background-secondary: ${config.yomi.theming.colors.rgba "base00"};
            --uc-transparent: rgba(0,0,0,0);
            --uc-selected: ${config.yomi.theming.colors.rgba "base07"};
            --uc-active: ${config.yomi.theming.colors.rgba "base07"};
            --uc-text: ${config.yomi.theming.colors.rgba "base0D"};
            --uc-panel-border: ${config.yomi.theming.colors.rgba "base01"};
            --uc-panel-border-ii: rgba(70, 70, 80, 0.2);
            --uc-context-menu: ${config.yomi.theming.colors.rgba "base01"};
            --uc-tabs-background: ${config.yomi.theming.colors.rgba "base00"};
            --uc-sb-background: ${config.yomi.theming.colors.rgba "base00"};
            --uc-sb-background-header: ${config.yomi.theming.colors.rgba "base01"};
            --uc-sb-background-container: var(--uc-transparent);
            --uc-tabs-lwt: color-mix(in srgb, var(--lwt-accent-color) 75%, #000);
            --uc-sb-lwt: color-mix(in srgb, var(--lwt-accent-color) 75%, #000);
            --urlbar-icon-border-radius: var(--uc-all-border-radius);
            --arrowpanel-menuitem-border-radius: var(--uc-all-border-radius);
            --arrowpanel-border-radius: var(--uc-all-border-radius);
            --toolbarbutton-border-radius: var(--uc-all-border-radius);
            --urlbar-icon-border-radius: var(--uc-all-border-radius);
            --button-border-radius: 10px;
            --uc-button-border-radius: 10px;
          }




          /* Overwriting existing variables -------------------------------------------------*/

          #main-window:not([lwtheme]), :root:not([lwtheme]) {

            --toolbar-bgcolor: var(--uc-ultima-window) !important;

            --tab-selected-bgcolor: var(--uc-active) !important;
            --tab-selected-textcolor: var(--uc-text) !important;
            --tab-loading-fill: var(--uc-accent-ii) !important;

            --button-hover-bgcolor: var(--uc-selected) !important;
            --toolbarbutton-hover-background: var(--uc-selected) !important;
            --button-active-bgcolor: var(--uc-active) !important;
            --toolbarbutton-active-background: var(--uc-active) !important;
            --button-primary-bgcolor: var(--uc-accent-i) !important;
            --button-primary-hover-bgcolor: var(--uc-accent-i) !important;
            --buttons-destructive-hover-bgcolor: var(--uc-accent-vi);  /*red*/
            --buttons-destructive-active-bgcolor: var(--uc-accent-vi); /*red*/
            --toolbarbutton-icon-fill: var(--uc-accent-ii) !important; /*toolbar button color*/

            --toolbar-field-background-color: var(--uc-accent-iv) !important;
            --toolbar-field-border-color: var(--uc-accent-iii) !important;
            --toolbar-field-focus-border-color: var(--uc-accent-v) !important;
            --urlbarView-result-button-selected-color: var(--uc-text) !important;
            --urlbarView-result-button-selected-background-color: var(--uc-selected) !important;
            --urlbarView-highlight-background: var(--uc-selected) !important;
            --urlbarView-hover-background: var(--uc-selected) !important;
            --urlbar-box-hover-bgcolor: var(--uc-selected) !important;
            --urlbar-box-hover-text-color: var(--uc-text) !important;

            --toolbar-field-color: var(--uc-text) !important;
            --toolbar-field-focus-color: var(--uc-text) !important;
            --toolbar-color: var(--uc-text) !important;
            --toolbar-field-color: var(--uc-text) !important;
            --toolbar-field-focus-color: var(--uc-text) !important;

            --sidebar-text-color: var(--uc-text) !important;
            --arrowpanel-background: var(--uc-background-panel) !important;
            --arrowpanel-border-color: var(--uc-active) !important;
            --arrowpanel-color: var(--uc-text) !important;
            --newtab-background-color: var(--uc-tabs-background) !important;

            --panel-background: var(--uc-background-panel) !important;
            --panel-item-hover-bgcolor: var(--uc-selected) !important;
            --panel-banner-item-hover-bgcolor: var(--uc-selected) !important;
            --short-notification-background: var(--uc-accent-ii) !important;
            --panel-border-color: var(--uc-panel-border) !important;
            --organizer-toolbar-background: var(--uc-accent-iv) !important;
            --organizer-pane-background: var(--uc-accent-iv) !important;
            --organizer-content-background: var(--uc-accent-iv) !important;
            --organizer-hover-background: var(--uc-accent-iv) !important;
            --organizer-selected-background: var(--uc-selected) !important;
            --organizer-focus-selected-color: var(--uc-selected) !important;
            --organizer-outline-color: rgb(0,221,255) !important;
            --organizer-toolbar-field-background: var(--uc-accent-iv) !important;
            --organizer-toolbar-field-background-focused: rgb(66, 61, 98) !important;
            --content-select-background-image: none !important;
          }




          /* Applying variables to create the Dark Mode theme --------------------------------*/

          #main-window:not([lwtheme]) {

              /* main browser window background color */
              background-color: var(--uc-ultima-window) !important;
              & body {background: var(--uc-ultima-window) !important;}

              /* keep consistency with the navigation assets (including the tabs container) */
              & #navigator-toolbox {
                  background-color: var(--toolbar-bgcolor) !important;
                  border-bottom: 1px solid rgba(0,0,0,0) !important;
                  &:-moz-window-inactive {
                      background-color: var(--toolbar-bgcolor) !important;
                      color: var(--uc-text) !important;
                  }
              }

              /* content window */
              & #appcontent,
              & #browser,
              & #tabbrowser-tabbox,
              & #tabbrowser-tabpanels,
              & .browserSidebarContainer {
                  background: var(--toolbar-bgcolor) !important;
              }
              & .browserStack {
                  background: var(--uc-transparent) !important;
              }
              & #tabbrowser-tabpanels browser[type] {
                  outline: 3px solid var(--toolbar-bgcolor);
              }

              /* tabs container */
              & #tabbrowser-tabs {
                  background: transparent;
                  --tab-loading-fill: var(--uc-accent-i) !important;
              }

              /*tabs styling - for unselected and unpinned*/
              & .tab-label-container:not([selected=""],[pinned]) {
                  color: var(--uc-text) !important;
              }
              /*tabs styling - for selected tab*/
              & .tab-label-container[selected] {
                  color: var(--uc-accent-v) !important;
              }
              /* pinned tabs style */
              .tab-label-container[pinned] {
                  color: var(--uc-accent-vi) !important;
              }
              & .tabbrowser-tab[pinned=""] .tab-background,
              & .tabbrowser-tab[pinned="true"] .tab-background {
                  background-color: var(--tab-selected-bgcolor) !important;
              }
              /* tabs tooltip styling */
              & .tab-preview-container {
                  background-color: var(--uc-tabs-background) !important;
                  color: var(--uc-text) !important;
                  width: 225px !important;
                  border: 1px solid var(--uc-panel-border) !important;
              }

              /* URL bar */
              & #urlbar:is([focused="true"], & [open]) > #urlbar-background, & #searchbar:focus-within {
                  margin-top: 3px !important; /*new*/
                  background-color: var(--uc-context-menu) !important;
                  border-radius: var(--uc-all-border-radius) !important;
              }

              & #urlbar:is([focused="true"], & [open]) > #urlbar-background, & #searchbar:focus-within {
                  border-radius: var(--uc-all-border-radius) !important;
              }

              & #urlbar-background, & #searchbar {
                  background-color: var(--uc-accent-iv) !important;
                  border-radius: 10px !important;
                  border: 0 !important;
                  box-shadow: 0.1rem 0.4rem 0.4rem -0.1rem rgba(25,25,25,0.8);
              }

              & #urlbar[open] > #urlbar-background {
                  border-color: var(--uc-accent-iii) !important;
              }

              & #urlbar[breakout][breakout-extend] {
                  background-color: transparent !important;
                  border-radius: 10px;
              }

              & #urlbar-zoom-button {
                  background-color: var(--uc-active) !important;
                  margin-top:3px !important;
              }

              & .urlbarView-row {
                  &[selected] {
                      color: var(--uc-text) !important;
                  }
              }

              /* toolbar buttons */
              & .toolbarbutton-icon:hover,
              & .toolbarbutton-icon[open] {
                  background-color: var(--uc-selected) !important;
              }
              & #TabsToolbar #firefox-view-button:hover:not([open]) > .toolbarbutton-icon
                {background-color: var(--uc-selected) !important;}
              /* bookmark button in URL bar */
              & #star-button[starred] {
                fill-opacity: 1 !important;
                fill: var(--uc-accent-i) !important;
              }
              /* title bar buttons - min, max, close */
              & .titlebar-button {
                border-radius: var(--uc-button-border-radius);
              }
              & .titlebar-button:hover {
                background-color: var(--uc-selected) !important;
              }
              @media (-moz-platform: windows) {
                  .titlebar-close:hover {
                      background-color: var(--uc-accent-vi) !important;
                  }
              }

              /* other panels & extensions panel */
              & .panel-subview-body {
                  background: var(--uc-background-panel) !important;
              }
              & panelview,
              & #unified-extensions-view {
                  background: var(--uc-background-panel) !important;
              }

              /* drop down menus */
              & #ContentSelectDropdown > menupopup[customoptionstyling="true"]::part(arrowscrollbox) {
                  --panel-color: black !important;
              }

              & #ContentSelectDropdownPopup .menupopup-arrowscrollbox::part(content) {
                  --panel-color: black !important;
              }
              & #ContentSelectDropdownPopup menupopup,
              & #ContentSelectDropdownPopup panel {
                  --panel-color: black !important;
              }

              /* extra styling - bookmark toolbar adjustment */
              & #PersonalToolbar {background: var(--uc-transparent) !important;}

              /* extra styling - customize toolbar page */
              & #customization-container {background-color: var(--uc-ultima-window) !important;}

              /* menu popups */
              & .panel-subview-body {
                  background: color-mix(in srgb, var(--uc-background-panel) 10%, var(--ultima-window) 90%) !important;
              }
              & .menupopup-arrowscrollbox {
                  background-color: var(--uc-background-panel) !important;
              }

          } /* < end of Dark Mode Theme */




          /* Adapting to add-on-theme styling ------------------------------------------------*/

          #main-window[lwtheme] {

              /* main browser window background color */
              background-color: var(--lwt-accent-color) !important;
              & body {background: var(--lwt-accent-color) !important;}
              /*if (this) preference is applied, use (that) variable instead*/
              @media (-moz-bool-pref: "ultima.xstyle.lwtheme") {
                  background-color: var(--arrowpanel-background) !important;
                  & body {background: var(--arrowpanel-background) !important;}
              }

              /* keep consistency with the navigation assets (including the tabs container) */
              & #navigator-toolbox {
                  background-color: var(--toolbar-bgcolor) !important;
                  border-bottom: 1px solid rgba(0,0,0,0) !important;
                  &:-moz-window-inactive {
                      background-color: var(--toolbar-bgcolor) !important;
                      color: var(--uc-text) !important;
                  }
              }
              & #nav-bar {background: initial !important;}

              /* content window */
              & #appcontent,
              & #browser,
              & #tabbrowser-tabbox,
              & #tabbrowser-tabpanels,
              & .browserSidebarContainer {
                  background: var(--uc-transparent) !important;
              }
              & .browserStack {
                  background: var(--uc-transparent) !important;
              }
              & #tabbrowser-tabpanels browser[type] {
                  margin-top: 2px !important; /*new*/
                  outline: 3px solid var(--lwt-accent-color);
                  @media (-moz-bool-pref: "ultima.xstyle.lwtheme") {
                      outline: 3px solid var(--arrowpanel-background);
                  }
              }

              /* side bar*/
              & #sidebar-header, & #sidebar {
                  background-color: var(--uc-sb-lwt) !important;
              }
              & #sidebar-box {
                  background-color: var(--uc-transparent) !important;
                  box-shadow: 0.1rem 0.3rem 0.4rem -0.1rem rgba(25,25,25,0.4);
              }
              & #sidebar-search-container #search-box, & #sidebar-search-container #viewButton {
                  appearance: none !important;
                  border-radius: 10px !important;
                  background-color: var(--uc-accent-iv) !important;
                  box-shadow: 0.1rem 0.3rem 0.4rem -0.1rem rgba(25,25,25,0.8);
              }
              & #bookmarksPanel #sidebar-search-container #search-box {
                  appearance: none !important;
                  border-radius: 10px !important;
                  background-color: var(--uc-accent-iv) !important;
              }
              & .sidebar-panel[lwt-sidebar] {
                  background-color: var(--uc-transparent) !important;
              }

              /* tabs and tabs container */
              --tab-selected-bgcolor: var(--lwt-accent-color) !important;
              @media (-moz-bool-pref: "ultima.xstyle.lwtheme") {
                  * {
                  --uc-tabs-lwt: color-mix(in srgb, var(--uc-background-main) 30%, var(--arrowpanel-background) 70%);
                  --tab-selected-bgcolor: var(--uc-background-main) !important;
                  }
              }
              & :root:not([customizing]) #tabbrowser-tabs:-moz-lwtheme {
                  background-color: var(--uc-tabs-lwt) !important;
              }
              & #TabsToolbar-customization-target {
                  background: var(--uc-tabs-lwt) !important;
              }
              /* pinned tabs style */
              & .tab-content[pinned=""] .tab-background,
              & .tab-content[pinned="true"] .tab-background {
                  background: var(--lwt-accent-color);
              }
              & .tabbrowser-tab[pending="true"] {
                  opacity: 0.3 !important;
              }

              /* URL bar */
              & #urlbar:is([focused="true"], & [open]) > #urlbar-background, & #searchbar:focus-within {
                  margin-top: 3px !important; /*new*/
                  background-color: color-mix(in srgb, var(--uc-background-main) 10%, var(--lwt-accent-color) 90%) !important;
                  border-radius: var(--uc-all-border-radius) !important;
              }

              & #urlbar:is([focused="true"], & [open]) > #urlbar-background, & #searchbar:focus-within {
                  border-radius: var(--uc-all-border-radius) !important;
              }

              & #urlbar-background, & #searchbar {
                  background-color: var(--uc-accent-iv) !important;
                  border-radius: 10px !important;
                  border: 0 !important;
                  box-shadow: 0.1rem 0.4rem 0.4rem -0.1rem rgba(0,0,0,0.5);
              }

              & #urlbar[open] > #urlbar-background {
                  border-color: var(--uc-accent-iii) !important;
              }

              & #urlbar[breakout][breakout-extend] {
                  background-color: transparent !important;
                  border-radius: 10px;
              }

              & #urlbar-zoom-button {
                  background-color: var(--uc-active) !important;
                  margin-top:3px !important;
              }

              & .urlbarView-row {
                  &[selected] {
                      color: var(--uc-text) !important;
                  }
              }

              /* extra styling - customize toolbar page */
              & #customization-container {background-color: var(--lwt-accent-color) !important;}

          } /* < end of Add-On Theme Styling */




          /* Global styling - applies everywhere ---------------------------------------------*/

          /* scroll bars */
          * {scrollbar-width:auto !important; scrollbar-color:rgba(50, 50, 60, 0.0) rgba(5,5,5, 0.0) !important;}
          #navigator-toolbox {scrollbar-width:auto !important; scrollbar-color:rgba(50, 50, 60, 0.3) rgba(5,5,5, 0.0) !important;}

          /* global dialog box */
          :root[dialogroot] {
            --in-content-page-background: var(--uc-background-solid) !important;
            color: var(--uc-text)  !important;
          }

          /* fix for inactive/unfocused window altering nav bar color */
          @media (-moz-platform: windows), (-moz-platform: linux) {
              root{--inactive-titlebar-opacity: 1 !important;}
          }

          /* tooltip, worth a try */
          tooltip {
              background-color: var(--uc-background-main) !important;
              color: var(--uc-text) !important;
              border-color: var(--uc-panel-border) !important;
          }

          /* side bar - font size, padding, borders, etc */
          #sidebar-header {
            font-size: 1.333em;
            padding: 7px !important;
            border-bottom: 0px !important;
          }
          #sidebar-close { /*side bar close button*/
              opacity: 0.6 !important;
          }
          /* bookmarks, history, splitter */
          #sidebar-search-container #search-box {
              height: 3em;
          }
          splitter {@media (-moz-platform: windows) { & {
            border-width: 0 0px !important;
            border-style: solid !important;
            background-color: transparent !important;
          } } }
          @media not (-moz-platform: linux) { .sidebar-splitter {
            border: 0 solid !important;
            border-inline-end-width: 1px !important;
            border-color: transparent !important;
            min-width: 1px !important;
            width: 4px !important;
            background-color: transparent !important;
            margin-inline-start: -7px !important;
          } }


          /*new experimental status for side bar - keeping a universal style*/

          #sidebar-header {
              background-color: var(--uc-sb-background-header) !important;
          }
          #sidebar {
              background: var(--uc-sb-background) !important;
          }
          #sidebar-box {
              background-color: transparent !important;
              box-shadow: 0.1rem 0.3rem 0.4rem -0.1rem rgba(25,25,25,0.7);
          }
          #sidebar-search-container #search-box, & #sidebar-search-container #viewButton {
              appearance: none !important;
              border-radius: 10px !important;
              background-color: var(--uc-accent-iv) !important;
              box-shadow: 0.1rem 0.3rem 0.4rem -0.1rem rgba(25,25,25,0.8);
          }
          #bookmarksPanel #sidebar-search-container #search-box {
              appearance: none !important;
              border-radius: 10px !important;
              background-color: var(--uc-accent-iv) !important;
          }

          /* title bar buttons - min max close*/
          #main-window {
              &:not([lwtheme]) .titlebar-button {
                  stroke: var(--toolbarbutton-icon-fill) !important;
              }
              &[lwtheme] .titlebar-button {
                  stroke: var(--toolbarbutton-icon-fill) !important;
              }
          }

          /* titlebar opacity safe guard, hopefully */
          :root { @media (-moz-platform: windows) {
            --inactive-titlebar-opacity: 1 !important;
          }}

          /* full screen indicator label */
          /*--the label that says ("website.com is now in full screen...")--*/
          #fullscreen-warning {
              &, *.pointerlockfswarning {
                  opacity: 0 !important;
                  border-radius: 20px !important;
              }
              & * {
                  border-radius: var(--uc-all-border-radius) !important;
              }
          }




          /* Global styling - Icons --------------==========----------------------------------*/

          @media (-moz-bool-pref: "ultima.theme.icons") {

              /*--extension menu--*/
              #main-window:not([lwtheme]) #unified-extensions-button {
                list-style-image: url("icons/extensions.svg") !important;
                fill: var(--toolbarbutton-icon-fill) !important;firefoxfirefox
              }
              #main-window[lwtheme] #unified-extensions-button {
                list-style-image: url("icons/extensions.svg") !important;
                fill: var(--lwt-accent-color) !important;
              }
              /*--bookmarks folder icon--*/
              .bookmark-item[container=true] {
                list-style-image: url("icons/bm.png") !important;
              }
              /*--ublock on--*/
              #ublock0_raymondhill_net-BAP image{
                list-style-image: url("icons/ubon.png") !important;
              }
              /*--ublock off--*/
              #ublock0_raymondhill_net-BAP[tooltiptext="uBlock Origin (off)"] image{
                list-style-image: url("icons/uboff.png") !important;
              }
              #forward-button image{
                list-style-image: url("chrome://global/skin/icons/arrow-right.svg") !important;
                stroke: var(--uc-accent-iii) !important;
              }
              #back-button image{
                list-style-image: url("chrome://global/skin/icons/arrow-left.svg") !important;
                stroke: var(--uc-accent-iii) !important;
              }
          }

          /*--notification badges--*/
          .toolbarbutton-badge {
            background-color: rgba(0,0,0,0.3) !important;
            box-shadow: 0 !important;
            color: var(--uc-text) !important;
            text-shadow: #FDFFFF 0.5px 0 15px!important;
          }

          }
        '';
    };
  };

  stylix.targets.firefox = {
    enable = false;
    profileNames = ["desmos" "monkey-type" "syncthing" "clockify" "proton-mail" "proton-drive" "excalidraw"];
  };

  # xdg.desktopEntries.zen = {
  #   name = "Zen Browser";
  #   genericName = "Web Browser";
  #   exec = "zen %U";
  #   terminal = false;
  #   categories = ["Application" "Network" "WebBrowser"];
  #   mimeType = ["text/html" "text/xml" "x-scheme-handler/http" "x-scheme-handler/https"];
  # };

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
  yomi.persistence.at.state.apps.firefox.directories = [
    ".mozilla/firefox" # More important stuff
  ];

  yomi.persistence.at.cache.apps.firefox.directories = [
    "${config.xdg.cacheHome}/mozilla/firefox" # Non important cache
  ];
  yomi.persistence.at.state.apps.zen.directories = [
    ".zen" # More important stuff
  ];

  yomi.persistence.at.cache.apps.zen.directories = [
    "${config.xdg.cacheHome}/zen" # Non important cache
  ];
  # }}}
}
