{config, ...}: {
  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
    options = [
      "--cmd cd"
    ];
  };
  # {{{ Persistence
  yomi.persistence.at.state.apps.zoxide = {
    directories = [
      "${config.xdg.dataHome}/zoxide"
    ];
  };
  # }}}
}
