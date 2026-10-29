# Zathura is the pdf reader I am using.
{config, ...}: {
  programs.zathura = {
    enable = true;
    extraConfig = with config.lib.stylix.colors.withHashtag; ''
      # {{{ Some arbitrary settings
      # Open document in fit-width mode by default
      set adjust-open "best-fit"

      # Roomier, easier-to-scan reading view
      set page-padding 8
      set page-right-to-left false
      set scroll-step 80
      set guioptions "sv"
      set statusbar-h-padding 12
      set statusbar-v-padding 8
      set smooth-reload true
      set selection-clipboard clipboard

      # Inject font
      set font "${config.stylix.fonts.sansSerif.name}"
      # }}}
      # {{{ Default foreground/background color
      set default-bg '${base00}'
      set default-fg ${base05}
      # }}}
      # {{{ Recolor
      set recolor 'true' # Allow recolor
      set recolor-keephue 'false' # Don't allow original hue when recoloring
      set recolor-reverse-video 'true' # Keep original image colors while recoloring

      # Opaque on purpose: a transparent light color lets the wallpaper bleed
      # through every recolored page and makes text hard to read.
      # Represent light/dark colors in recoloring mode
      set recolor-lightcolor '${base00}'
      set recolor-darkcolor '${base05}'
      # }}}
      # {{{ Completion
      # Command line completion entries
      set completion-fg '${base05}'
      set completion-bg '${base00}'

      # Command line completion group elements
      set completion-group-fg '${base02}'
      set completion-group-bg '${base00}'

      # Current command line completion element
      set completion-highlight-fg '${base00}'
      set completion-highlight-bg '${base05}'
      # }}}
      # {{{ Input bar
      set inputbar-fg '${base05}'
      set inputbar-bg '${base00}'
      # }}}
      # {{{ Notifications
      set notification-fg '${base05}'
      set notification-bg '${base00}'

      # Error notification
      set notification-error-fg '${base08}'
      set notification-error-bg '${base01}'

      # Warning notification
      set notification-warning-fg '${base0A}'
      set notification-warning-bg '${base01}'
      # }}}
      # {{{ Status bar
      set statusbar-fg '${base05}'
      set statusbar-bg '${base00}'
      # }}}
      # {{{ Highlighting parts of the document (e.g. show search results)
      # TODO: make sure these look fine on other schemes
      set highlight-color '${base03}'
      set highlight-active-color '${base06}'
      # }}}
      # {{{ 'Loading...' text
      set render-loading-fg '${base05}'
      set render-loading-bg '${base00}'
      # }}}
      # {{{ Index mode
      set index-fg '${base05}'
      set index-bg 'rgba(0,0,0.0)'

      # Selected element in index mode
      set index-active-fg '${base07}'
      set index-active-bg '${base03}'
      # }}}
    '';
  };

  # Hyprland dims every window to stylix.opacity.applications; a page of text
  # must stay solid.
  wayland.windowManager.hyprland.settings.window_rule = [
    {
      match.class = "^(org\\.pwmt\\.zathura|zathura)$";
      opacity = "1.0 override 1.0 override";
      no_blur = true;
    }
  ];

  home.shellAliases.pdf = "zathura --fork";

  # Make zathura the default app for opening pdfs.
  xdg.mimeApps.defaultApplications."application/pdf" = ["org.pwmt.zathura.desktop"];

  # {{{ Persistence
  yomi.persistence.at.state.apps.zathura.directories = [
    "${config.xdg.dataHome}/zathura"
  ];
  # }}}
}
