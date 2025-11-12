{
  lib,
  pkgs,
  config,
  ...
}: {
  programs.wofi = {
    enable = true;

    settings = {
      width = 600;
      height = 400;
      location = "center";
      show = "drun";
      prompt = "Search...";
      filter_rate = 100;
      allow_markup = true;
      no_actions = true;
      halign = "fill";
      orientation = "vertical";
      content_halign = "fill";
      insensitive = true;
      allow_images = true;
      image_size = 40;
      gtk_dark = true;
      layer = "overlay";
    };

    style =
      /*
      css
      */
      ''
        * {
          font-size: 1rem;
          outline: none;
          font-family: "${config.stylix.fonts.sansSerif.name}";
        }

        window {
          margin: 0px;
          border: 3px solid ${config.lib.stylix.colors.withHashtag.base0D};
          background-color: rgba(${config.yomi.theming.colors.rgba "base00"});
          border-radius: ${toString config.yomi.theming.rounding.radius}px;
        }

        #input {
          margin: ${toString config.yomi.theming.gaps.inner}px;
          padding: ${toString config.yomi.theming.gaps.inner}px;
          border: 3px solid ${config.lib.stylix.colors.withHashtag.base0D};
          background-color: rgba(${config.yomi.theming.colors.rgba "base00"});
          color: ${config.lib.stylix.colors.withHashtag.base05};
          border-radius: ${toString config.yomi.theming.rounding.radius}px;
        }

        #inner-box {
          margin: ${toString config.yomi.theming.gaps.inner}px;
          border: none;
          background-color: rgba(${config.yomi.theming.colors.rgba "base00"});
        }

        #outer-box {
          margin: 0px;
          border: none;
          background-color: rgba(${config.yomi.theming.colors.rgba "base00"});
        }

        #scroll {
          margin: 0px;
          border: none;
        }

        #text {
          margin: ${toString (config.yomi.theming.gaps.inner / 2)}px;
          border: none;
          color: ${config.lib.stylix.colors.withHashtag.base05};
        }

        #entry {
          margin: ${toString (config.yomi.theming.gaps.inner / 2)}px;
          border: none;
          border-radius: ${toString config.yomi.theming.rounding.radius}px;
          background-color: transparent;
        }

        #entry:selected {
          background-color: rgba(${config.yomi.theming.colors.rgb "base03"}, 0.2);
          border: 3px solid ${config.lib.stylix.colors.withHashtag.base0D};
        }

        #img {
          margin-right: ${toString config.yomi.theming.gaps.inner}px;
        }
      '';
  };
}
