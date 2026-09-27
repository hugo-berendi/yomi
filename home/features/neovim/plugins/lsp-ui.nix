{pkgs, ...}: {
  programs.nvf.settings.vim.extraPlugins = {
    # {{{ tiny-inline-diagnostic
    # Diagnostics as wrapped bubbles under the cursor line instead of
    # virtual text running off the edge (nvf leaves virtual_text off).
    tiny-inline-diagnostic = {
      package = pkgs.vimPlugins.tiny-inline-diagnostic-nvim;
      setup = ''
        require("tiny-inline-diagnostic").setup({
          preset = "modern",
          options = {
            show_source = { enabled = true, if_many = true },
            multilines = { enabled = true },
            break_line = { enabled = true, after = 80 },
          },
        })
      '';
    };
    # }}}
    # {{{ inc-rename
    # Live preview of every occurrence while typing the new name; noice's
    # inc_rename preset gives it a popup. Mapped on <leader>cr.
    inc-rename = {
      package = pkgs.vimPlugins.inc-rename-nvim;
      setup = ''require("inc_rename").setup({})'';
    };
    # }}}
    # {{{ treesj
    # Toggle a list, attrset or argument list between one and many lines.
    treesj = {
      package = pkgs.vimPlugins.treesj;
      setup = ''
        require("treesj").setup({ use_default_keymaps = false, max_join_length = 150 })
        vim.keymap.set("n", "gS", require("treesj").toggle, { desc = "Split/Join" })
      '';
    };
    # }}}
  };
}
