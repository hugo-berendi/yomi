{
  lib,
  pkgs,
  config,
  ...
}: {
  services.walker = {
    enable = true;
    systemd.enable = true;

    settings = {
      placeholder = "Search...";
      show_icons = true;
      icon_size = 40;
      modules = [
        {name = "applications";}
        {name = "clipboard";}
      ];
    };

    theme.style =
      /*
      css
      */
      ''
        * {
          font-size: 1rem;
          font-family: "${config.stylix.fonts.sansSerif.name}";
        }

        #window {
          background-color: rgba(${config.yomi.theming.colors.rgba "base00"});
          border: 3px solid ${config.lib.stylix.colors.withHashtag.base0D};
          border-radius: ${toString config.yomi.theming.rounding.radius}px;
        }

        #box {
          margin: ${toString config.yomi.theming.gaps.inner}px;
        }

        #entry {
          padding: ${toString config.yomi.theming.gaps.inner}px;
          border: 3px solid ${config.lib.stylix.colors.withHashtag.base0D};
          background-color: rgba(${config.yomi.theming.colors.rgba "base00"});
          color: ${config.lib.stylix.colors.withHashtag.base05};
          border-radius: ${toString config.yomi.theming.rounding.radius}px;
        }

        #entry:focus {
          border-color: ${config.lib.stylix.colors.withHashtag.base0D};
        }

        #list {
          margin-top: ${toString config.yomi.theming.gaps.inner}px;
          background-color: transparent;
        }

        .item {
          padding: ${toString (config.yomi.theming.gaps.inner / 2)}px;
          border-radius: ${toString config.yomi.theming.rounding.radius}px;
          background-color: transparent;
        }

        .item:selected {
          background-color: rgba(${config.yomi.theming.colors.rgb "base03"}, 0.2);
          border: 3px solid ${config.lib.stylix.colors.withHashtag.base0D};
        }

        .item label {
          color: ${config.lib.stylix.colors.withHashtag.base05};
        }

        .item:selected label {
          color: ${config.lib.stylix.colors.withHashtag.base05};
        }

        .icon {
          margin-right: ${toString config.yomi.theming.gaps.inner}px;
        }
      '';
  };
}
