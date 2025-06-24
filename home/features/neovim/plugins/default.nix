{
  imports = [
    # {{{ snippets
    ./snippets/luasnip.nix
    # }}}
    # {{{ lsp
    ./lsp/lsp.nix
    ./lsp/conform.nix
    ./lsp/trouble.nix
    # }}}
    # {{{ editor
    ./editor/treesitter.nix
    ./editor/wakatime.nix
    ./editor/vim-css-colors.nix
    ./editor/presence.nix
    # }}}
    # {{{ cmp
    ./cmp/cmp.nix
    ./cmp/lspkind.nix
    ./cmp/autopairs.nix
    ./cmp/cmp-copilot.nix
    ./cmp/schemastore.nix
    # }}}
    # {{{ ui
    ./ui/dressing.nix
    ./ui/dashboard.nix
    ./ui/lualine.nix
    ./ui/rainbow-delimiters.nix
    # }}}
    # {{{ utils
    ./utils/telescope.nix
    ./utils/obsidian.nix
    ./utils/ts-autotag.nix
    ./utils/yazi.nix
    ./utils/mini.nix
    # }}}
    # {{{ filetypes
    ./filetypes/markdown.nix
    ./filetypes/latex.nix
    # }}}
  ];

  programs.nixvim.plugins = {
    noice = {
      enable = true;
    };
    todo-comments = {
      enable = true;
    };
    which-key = {
      enable = true;
      settings = {};
    };
  };
}
