{
  lib,
  config,
  ...
}: {
  programs.waybar.style =
    /*
    css
    */
    ''
      * {
        font-family: "${config.stylix.fonts.sansSerif.name}", "Font Awesome 6 Free", Roboto, Helvetica, Arial,
          sans-serif;
        font-size: ${toString config.stylix.fonts.sizes.desktop}pt;
        min-height: 0;
        border-radius: ${toString config.yomi.theming.rounding.radius}px;
      }

      window#waybar {
        background: transparent;
        color: ${config.lib.stylix.colors.withHashtag.base0D};
      }

      #workspaces {
        margin-right: 5px;
        margin-top: 5px;
        margin-bottom: 5px;
        padding: 8px;
        font-weight: normal;
        font-style: normal;
        transition: all 0.3s ease-in-out;
      }

      #workspaces button {
        padding: 0px;
        margin: 0 3px;
        min-width: 30px;
        color: ${config.lib.stylix.colors.withHashtag.base0D};
        background: ${config.lib.stylix.colors.withHashtag.base0D};
        transition: all 0.3s ease-in-out;
        opacity: 0.4;
        font-size: 10;
      }

      #workspaces button.active {
        color: ${config.lib.stylix.colors.withHashtag.base0D};
        background: ${config.lib.stylix.colors.withHashtag.base0D};
        min-width: 50px;
        background-size: 400% 400%;
        opacity: 1;
      }

      #workspaces button:hover {
        background: ${config.lib.stylix.colors.withHashtag.base0D};
        color: ${config.lib.stylix.colors.withHashtag.base0D};
        min-width: 50px;
        background-size: 400% 400%;
      }

      #tray,
      #custom-spotify,
      #custom-updates,
      #workspaces,
      #disk,
      #cpu,
      #memory,
      #network,
      #pulseaudio,
      #battery,
      #clock,
      #custom-power,
      #bluetooth,
      #custom-weather,
      tooltip,
      #custom-dexcom,
      #custom-music {
        background: rgba(${config.yomi.theming.colors.rgba "base00"});
        border-width: ${toString config.yomi.theming.rounding.size}px;
        border-style: solid;
        border-color: ${config.lib.stylix.colors.withHashtag.base0D};
        margin-top: 5px;
        margin-bottom: 5px;
        padding-top: 5px;
        padding-bottom: 5px;
      }

      #tray {
        padding-left: 5px;
        padding-right: 5px;
      }

      tooltip {
        padding: 20px;
        margin-top: 30px;
      }

      /* left of a group */
      #network,
      #disk {
        border-right-style: none;
        border-radius: ${toString config.yomi.theming.rounding.radius} 0 0 ${toString config.yomi.theming.rounding.radius};
        margin-left: 5px;
        padding-left: 15px;
        padding-right: 3px;
      }

      /* middle of a group */
      #pulseaudio,
      #battery,
      #cpu,
      #bluetooth,
      #clock {
        border-right-style: none;
        border-left-style: none;
        border-radius: 0 0 0 0;
        padding-right: 2px;
        padding-left: 2px;
      }

      /* right of a group */
      #custom-weather,
      #memory {
        border-left-style: none;
        border-radius: 0 ${toString config.yomi.theming.rounding.radius} ${toString config.yomi.theming.rounding.radius} 0;
        margin-right: 5px;
        padding-right: 15px;
        padding-left: 3px;
      }

      #custom-updates {
        margin-top: 5px;
        margin-bottom: 5px;
        margin-right: 5px;
        margin-left: 5px;
        padding-right: 15px;
        padding-left: 15px;
      }

      #bluetooth {
        padding-right: 15px;
        color: @pine;
      }

      #pulseaudio {
        padding-right: 8px;
      }

      #network {
        padding-left: 15px;
        padding-right: 0px;
        margin-top: 5px;
        margin-bottom: 5px;
      }

      #custom-spotify, #custom-music {
        margin-top: 5px;
        margin-bottom: 5px;
        margin-left: 5px;
        padding-right: 15px;
        padding-left: 15px;
      }

      #custom-power {
        margin-top: 5px;
        margin-bottom: 5px;
        margin-left: 5px;
        padding-right: 10px;
        padding-left: 10px;
      }

      #custom-weather .severe {
        color: #eb937d;
      }

      #custom-weather .sunnyDay {
        color: #c2ca76;
      }

      #custom-weather .clearNight {
        color: #2b2b2a;
      }

      #custom-weather .cloudyFoggyDay,
      #custom-weather .cloudyFoggyNight {
        color: #c2ddda;
      }

      #custom-weather .rainyDay,
      #custom-weather .rainyNight {
        color: #5aaca5;
      }

      #custom-weather .showyIcyDay,
      #custom-weather .snowyIcyNight {
        color: #d6e7e5;
      }

      #custom-weather .default {
        color: #dbd9d8;
      }

      #custom-weather {
        padding-left: 10px;
      }

      #custom-dexcom .doubleup,
      #custom-dexcom .doubledown {
        color: ${config.lib.stylix.colors.withHashtag.base08};
      }

      #custom-dexcom .up,
      #custom-dexcom .down {
        color: ${config.lib.stylix.colors.withHashtag.base0A};
      }

      #custom-dexcom .right {
        color: ${config.lib.stylix.colors.withHashtag.base0C};
      }

      #custom-dexcom {
        padding-right: 15px;
        padding-left: 10px;
        margin-right: 5px;
      }
    '';
}
