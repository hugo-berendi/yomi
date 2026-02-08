{pkgs, ...}: {
  programs.nvf.settings.vim.autocomplete = {
    nvim-cmp = {
      enable = true;
      mappings = {
        complete = "<C-Space>";
        confirm = "<CR>";
        next = "<Tab>";
        previous = "<S-Tab>";
        close = "<C-e>";
        scrollDocsUp = "<C-b>";
        scrollDocsDown = "<C-f>";
      };
      sources = {
        nvim_lsp = "[LSP]";
        buffer = "[Buffer]";
        path = "[Path]";
      };
      sourcePlugins = [
        pkgs.vimPlugins.cmp-nvim-lsp
        pkgs.vimPlugins.cmp_luasnip
      ];
    };
  };

  programs.nvf.settings.vim.snippets.luasnip.enable = true;
}
