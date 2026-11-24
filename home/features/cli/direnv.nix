{config, ...}: let
  statePath = "${config.xdg.dataHome}/direnv/allow";
in {
  programs.direnv = {
    enable = true;
    silent = true;
    nix-direnv.enable = true;
    # enableFishIntegration = true; # is enabled by default
  };

  # Only save allowed paths for 30d
  systemd.user.tmpfiles.rules = ["d ${statePath} - - - 30d"];
  yomi.persistence.at.state.apps.direnv.directories = [statePath];
}
