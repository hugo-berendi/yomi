{config, ...}: let
  enabled =
    if config.yomi.toggles.isServer.enable
    then false
    else true;
in {
  programs.nixvim.plugins = {
    presence = {
      enable = enabled;
      settings.neovim_image_text = "The true editor";
    };
  };
}
