{...}: {
  programs.nixvim.plugins = {
    presence-nvim = {
      enable = true;
      neovimImageText = "The true editor";
    };
  };
}
