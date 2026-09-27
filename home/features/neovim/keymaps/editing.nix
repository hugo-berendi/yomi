let
  move = fn: query: ''function() require("nvim-treesitter-textobjects.move").${fn}("${query}", "textobjects") end'';
in {
  programs.nvf.settings.vim.keymaps = [
    # {{{ Yanky
    {
      mode = ["n" "x"];
      key = "p";
      action = "<Plug>(YankyPutAfter)";
      desc = "Put After";
    }
    {
      mode = ["n" "x"];
      key = "P";
      action = "<Plug>(YankyPutBefore)";
      desc = "Put Before";
    }
    {
      mode = "n";
      key = "[y";
      action = "<Plug>(YankyCycleForward)";
      desc = "Cycle Yank Forward";
    }
    {
      mode = "n";
      key = "]y";
      action = "<Plug>(YankyCycleBackward)";
      desc = "Cycle Yank Backward";
    }
    {
      mode = "n";
      key = "<leader>p";
      action = "<cmd>YankyRingHistory<cr>";
      desc = "Yank History";
    }
    # }}}
    # {{{ Treesitter moves
    # ]c/[c stay with diff mode; classes use ]C/[C.
    {
      mode = ["n" "x" "o"];
      key = "]f";
      action = move "goto_next_start" "@function.outer";
      lua = true;
      desc = "Next Function";
    }
    {
      mode = ["n" "x" "o"];
      key = "[f";
      action = move "goto_previous_start" "@function.outer";
      lua = true;
      desc = "Prev Function";
    }
    {
      mode = ["n" "x" "o"];
      key = "]C";
      action = move "goto_next_start" "@class.outer";
      lua = true;
      desc = "Next Class";
    }
    {
      mode = ["n" "x" "o"];
      key = "[C";
      action = move "goto_previous_start" "@class.outer";
      lua = true;
      desc = "Prev Class";
    }
    # }}}
    # {{{ Snacks zen, dim, scratch
    {
      mode = "n";
      key = "<leader>uz";
      action = "<cmd>lua Snacks.zen()<cr>";
      desc = "Zen Mode";
    }
    {
      mode = "n";
      key = "<leader>uZ";
      action = "<cmd>lua Snacks.zen.zoom()<cr>";
      desc = "Zoom Window";
    }
    {
      mode = "n";
      key = "<leader>uD";
      action = ''function() if Snacks.dim.enabled then Snacks.dim.disable() else Snacks.dim.enable() end end'';
      lua = true;
      desc = "Toggle Dim";
    }
    {
      mode = "n";
      key = "<leader>.";
      action = "<cmd>lua Snacks.scratch()<cr>";
      desc = "Scratch Buffer";
    }
    {
      mode = "n";
      key = "<leader>S";
      action = "<cmd>lua Snacks.scratch.select()<cr>";
      desc = "Select Scratch Buffer";
    }
    # }}}
  ];
}
