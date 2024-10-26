{config, ...}: let
  enabled =
    if config.yomi.toggles.isServer.enable
    then false
    else true;
in {
  programs.nixvim.plugins = {
    presence-nvim = {
      enable = enabled;
      neovimImageText = "The true editor";
    };
  };
}
