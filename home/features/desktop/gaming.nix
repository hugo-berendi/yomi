{
  config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    legendary-gl
    rare
    lutris
  ];
  # {{{ Persistence
  satellite.persistence.at.state.apps.steam = {
    directories = [
      ".factorio"
      "${config.xdg.dataHome}/Steam"
    ];
  };
  # }}}
}
