{
  inputs,
  lib,
  pkgs,
  config,
  ...
}: let
  normal-plugins = with inputs.anyrun.packages.${pkgs.stdenv.hostPlatform.system}; [
    dictionary
    rink
    stdin
    websearch
    translate
    kidex
  ];
in {
  programs.anyrun = {
    enable = true;
    config = {
      # {{{ Plugins
      plugins = [
        inputs.anyrun-plugins.packages.${pkgs.stdenv.hostPlatform.system}.cliphist
        inputs.anyrun-plugins.packages.${pkgs.stdenv.hostPlatform.system}.applications
        inputs.anyrun-plugins.packages.${pkgs.stdenv.hostPlatform.system}.symbols
      ];
      # }}}
      # {{{ Geometry
      x.fraction = 0.5;
      y.fraction = 0.3;
      width.fraction = 0.3;
      height.fraction = 0.5;

      hidePluginInfo = true;
      closeOnClick = true;
      showResultsImmediately = false;
      maxEntries = 10;
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

    extraConfigFiles."cliphist.ron".text = ''
      Config(
        cliphist_path: "${lib.getExe pkgs.cliphist}",
        max_entries: 10,
        prefix: ":v",
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
          border: 3px solid ${config.lib.stylix.colors.withHashtag.base0D};
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
          border: 3px solid ${config.lib.stylix.colors.withHashtag.base0D};
          border-radius: ${toString config.yomi.theming.rounding.radius}px;

        }
        /* }}} */
        /* {{{ Matches */
        row#match {
          margin: 0.7rem;
          margin-bottom: 0.3rem;
          color: ${config.lib.stylix.colors.withHashtag.base05};
          padding: 0.5rem;
          transition: none;
        }

        row#match:last-child {
          margin-bottom: 0.7rem;
        }

        #match:selected {
          padding: 0.5rem;
          color: ${config.lib.stylix.colors.withHashtag.base05};
          background: rgba(${config.yomi.theming.colors.rgb "base03"}, 0.2);
        }
        /* }}} */
      '';
  };
}
