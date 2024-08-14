{
  inputs,
  pkgs,
  config,
  osConfig,
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
          inputs.anyrun-nixos-options.packages.${pkgs.system}.default
        ];
      # }}}
      # {{{ Geometry
      x.fraction = 0.5;
      y.fraction = 0.3;
      width.fraction = 0.3;

      hidePluginInfo = true;
      closeOnClick = true;
      showResultsImmediately = true;
      maxEntries = 5;
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

    extraConfigFiles."nixos-options.ron".text = let
      #               ↓ home-manager refers to the nixos configuration as osConfig
      nixos-options = osConfig.system.build.manual.optionsJSON + "/share/doc/nixos/options.json";
      hm-options = inputs.home-manager.packages.${pkgs.system}.docs-json + "/share/doc/home-manager/options.json";
      # merge your options
      options = builtins.toJSON {
        ":no" = [nixos-options];
        ":hmo" = [hm-options];
      };
      # or alternatively if you wish to read any other documentation options, such as home-manager
      # get the docs-json package from the home-manager flake
      # options = builtins.toJSON {
      #   ":something-else" = [some-other-option];
      #   ":nall" = [nixos-options hm-options some-other-option];
      # };
    in ''
      Config(
          // add your option paths
          options: ${options},
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
          font-size: 1.5rem;
          outline: none;
        }
        /* }}} */
        /* {{{ Transparent & raised surfaces */
        #entry,
        list#main,
        row#match:selected {
          box-shadow: 0.5px 0.5px 1.5px 1.5px rgba(0, 0, 0, 0.5);
          border-radius: ${toString config.satellite.theming.rounding.radius}px;
          border: 3px solid ${config.lib.stylix.scheme.withHashtag.base08};
        }

        #entry,
        list#main {
          margin: 1rem;
          background: rgba(${config.satellite.theming.colors.rgba "base00"});
          min-height: 1rem;
        }
        /* }}} */
        /* {{{ Input */
        #entry {
          font-size: 1.5rem;
          padding: 1rem;
          border: 3px solid ${config.lib.stylix.scheme.withHashtag.base08};
          border-radius: ${toString config.satellite.theming.rounding.radius}px;

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
          background: rgba(${config.satellite.theming.colors.rgb "base03"}, 0.2);
        }
        /* }}} */
      '';
  };
}
