{
  programs.nixvim = {
    plugins.copilot-cmp = {
      enable = true;
    };

    plugins.copilot-lua = {
      enable = true;
      settings = {
        suggestion = {enabled = false;};
        panel = {enabled = false;};
      };
    };

    extraConfigLua = ''
      require("copilot").setup({
        suggestion = { enabled = true },
        panel = { enabled = false },
      })
    '';
  };
}
