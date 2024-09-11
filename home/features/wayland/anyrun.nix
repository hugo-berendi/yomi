{
  inputs,
  pkgs,
  config,
  ...
}: let
  normal-plugins = with inputs.anyrun.packages.${pkgs.system}; [
    applications
    dictionary
    rink
    stdin
    # symbols # Looks ugly atm
    websearch
    translate
    kidex
  ];
in {
  programs.anyrun = {
    enable = true;
    config = {
      # {{{ Plugins
      plugins =
        normal-plugins
        ++ [
        ];
      # }}}
      # {{{ Geometry
      x.fraction = 0.5;
      y.fraction = 0.3;
      width.fraction = 0.3;
      height.fraction = 0.5;

      hidePluginInfo = true;
      closeOnClick = true;
      showResultsImmediately = true;
      maxEntries = null;
      layer = "overlay";
    };

    extraConfigFiles."websearch.ron".text = ''
      Config(
        prefix: "?",
        engines: [Custom(
          name: "Startpage",
          url: "startpage.com/do/search?q={}",
        )],
      )
    '';

    extraConfigFiles."translate.ron".text = ''
      Config(
        prefix: ":t",
        language_delimiter: ">",
        max_entries: 3,
      )
    '';

    extraCss =
      /*
      css
      */
      ''
        /* {{{ Global overrides */
        #window,
        #entry,
        #main,
        #plugin,
        #match {
          background: transparent;
        }

        * {
          font-size: 1rem;
          outline: none;
        }
        /* }}} */
        /* {{{ Transparent & raised surfaces */
        #entry,
        list#main,
        row#match:selected {
          box-shadow: 0.5px 0.5px 1.5px 1.5px rgba(0, 0, 0, 0.5);
          border-radius: ${toString config.yomi.theming.rounding.radius}px;
          border: 3px solid ${config.lib.stylix.scheme.withHashtag.base0D};
        }

        #entry,
        list#main {
          margin: 1rem;
          background: rgba(${config.yomi.theming.colors.rgba "base00"});
          min-height: 1rem;
        }
        /* }}} */
        /* {{{ Input */
        #entry {
          font-size: 1rem;
          padding: 1rem;
          border: 3px solid ${config.lib.stylix.scheme.withHashtag.base0D};
          border-radius: ${toString config.yomi.theming.rounding.radius}px;

        }
        /* }}} */
        /* {{{ Matches */
        row#match {
          margin: 0.7rem;
          margin-bottom: 0.3rem;
          color: ${config.lib.stylix.scheme.withHashtag.base05};
          padding: 0.5rem;
          transition: none;
        }

        row#match:last-child {
          margin-bottom: 0.7rem;
        }

        #match:selected {
          padding: 0.5rem;
          color: ${config.lib.stylix.scheme.withHashtag.base05};
          background: rgba(${config.yomi.theming.colors.rgb "base03"}, 0.2);
        }
        /* }}} */
      '';
  };
}
