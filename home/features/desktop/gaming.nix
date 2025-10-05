{
  config,
  pkgs,
  ...
}: {
  # {{{ Packages
  home.packages = with pkgs; [
    legendary-gl
    rare
    heroic
    mangohud
    gamemode
    lutris
    protonplus
  ];
  # }}}
  # {{{ Styling
  stylix.targets = {
    mangohud.enable = true;
  };
  # }}}
  # {{{ Persistence
  yomi.persistence.at.state.apps = {
    steam.directories = [
      ".factorio"
      "${config.xdg.dataHome}/Terraria"
      "${config.xdg.dataHome}/Steam"
    ];
    heroic.directories = [
      "media/games/heroic"
    ];
  };
  # }}}
}
