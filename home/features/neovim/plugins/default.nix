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
    # }}}
    # {{{ cmp
    ./cmp/cmp.nix
    ./cmp/lspkind.nix
    ./cmp/autopairs.nix
    # }}}
    # {{{ ui
    ./ui/dressing.nix
    ./ui/startup.nix
    ./ui/lualine.nix
    # }}}
    # {{{ utils
    ./utils/telescope.nix
    # }}}
    # {{{ filetypes
    ./filetypes/markdown.nix
    # }}}
  ];
}
