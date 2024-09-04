{
  config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    legendary-gl # cli tool for epic games launcher
    rare # ui client for legendary
    heroic # maybe better than rare
    mangohud # show stats (like fps) using a game overlay
    gamemode # run games better on linux
    lutris # wrapper for most game stores
    protonplus # manage proton (ge) and wine
  ];
  # {{{ Styling
  stylix.targets = {
    mangohud.enable = true;
  };
  # }}}
  # {{{ Persistence
  satellite.persistence.at.state.apps.steam = {
    directories = [
      ".factorio"
      "${config.xdg.dataHome}/Steam"
      "${config.xdg.dataHome}/Terraria"
    ];
  };
  satellite.persistence.at.state.apps.heroic = {
    directories = [
      "media/games/heroic"
    ];
  };
  # }}}
}
