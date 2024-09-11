{config, ...}: let
  statePath = "${config.xdg.dataHome}/direnv/allow";
in {
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    # enableFishIntegration = true;
  };

  home.sessionVariables = {
    # No more long command warnings
    DIRENV_WARN_TIMEOUT = "24h";
    # No more usesless logs
    DIRENV_LOG_FORMAT = "";
  };

  # Only save allowed paths for 30d
  systemd.user.tmpfiles.rules = ["d ${statePath} - - - 30d"];
  yomi.persistence.at.state.apps.direnv.directories = [statePath];
}
