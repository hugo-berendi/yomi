{config, ...}: {
  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
    options = [
      "--cmd cd"
    ];
  };
  # {{{ Persistence
  satellite.persistence.at.state.apps.zoxide = {
    directories = [
      "${config.xdg.dataHome}/zoxide"
    ];
  };
  # }}}
}
