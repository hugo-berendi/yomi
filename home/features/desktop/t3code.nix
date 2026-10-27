{config, ...}: {
  # {{{ T3 Code
  # ~/.t3 holds the server's sessions. The desktop app's own Electron profile
  # is separate, and it is where the UI keeps its settings -- installed
  # themes included, in localStorage under `t3code:themes:v1`. Unpersisted,
  # it came back empty on every boot, so an imported theme lasted until the
  # next reboot and only the built-in ones ever seemed to exist.
  yomi.persistence.at.state.apps.t3code.directories = [
    "${config.home.homeDirectory}/.t3"
    "${config.xdg.configHome}/T3 Code (Alpha)"
  ];

  # T3 Code has no theme directory to drop this into; the library lives in
  # localStorage. Import it once through Settings -> Colors & themes ->
  # Import, which now survives reboots. Roles left out fall back to the
  # built-in dark theme, and the import accepts any CSS colour, hex included.
  xdg.dataFile."t3code/stylix.json".text = let
    c = config.lib.stylix.colors.withHashtag;
  in
    builtins.toJSON {
      version = 1;
      id = "stylix";
      name = "Stylix (${config.lib.stylix.colors.scheme})";
      appearance = config.stylix.polarity;
      colors = {
        canvas = c.base00;
        chrome = c.base00;
        toolbar = c.base00;
        toolbarForeground = c.base05;
        toolbarBorder = c.base02;
        toolbarControl = c.base01;
        toolbarControlForeground = c.base05;
        toolbarControlHover = c.base02;
        surface = c.base01;
        surfaceRaised = c.base01;
        surfaceOverlay = c.base01;
        text = c.base05;
        textMuted = c.base04;
        border = c.base02;
        input = c.base02;
        focus = c.base0D;
        accent = c.base0D;
        accentForeground = c.base00;
        secondary = c.base02;
        secondaryForeground = c.base05;
        muted = c.base02;
        mutedForeground = c.base04;
        placeholder = c.base03;
        secondaryLabel = c.base04;
        iconMuted = c.base04;
        error = c.base08;
        errorForeground = c.base08;
        errorSurface = c.base01;
        warning = c.base09;
        warningForeground = c.base09;
        warningSurface = c.base01;
        update = c.base0C;
        updateForeground = c.base0C;
        updateSurface = c.base01;
        accentSurface = c.base02;
        accentSurfaceForeground = c.base05;
        messageSurface = c.base01;
        messageForeground = c.base05;
        messageAction = c.base0D;
        messageActionForeground = c.base00;
        messageActionHover = c.base0E;
        codeBackground = c.base01;
        codeForeground = c.base05;
        sidebar = c.base01;
        sidebarForeground = c.base05;
        sidebarMutedForeground = c.base04;
        sidebarControlSurface = c.base02;
        sidebarRowHover = c.base02;
        sidebarRowActive = c.base02;
        sidebarRowSelected = c.base02;
        sidebarBorder = c.base02;
        terminalBackground = c.base00;
        terminalForeground = c.base05;
        terminalCursor = c.base05;
        terminalSelection = c.base02;
        terminalScrollbar = c.base02;
        terminalScrollbarHover = c.base03;
      };
    };
  # }}}
}
