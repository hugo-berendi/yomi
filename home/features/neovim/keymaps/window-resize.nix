_: {
  programs.nvf.settings.vim.keymaps = [
    # {{{ Window resize
    {
      mode = "n";
      key = "<C-Up>";
      action = "<cmd>resize +2<cr>";
      desc = "Increase Window Height";
    }
    {
      mode = "n";
      key = "<C-Down>";
      action = "<cmd>resize -2<cr>";
      desc = "Decrease Window Height";
    }
    {
      mode = "n";
      key = "<C-Left>";
      action = "<cmd>vertical resize -2<cr>";
      desc = "Decrease Window Width";
    }
    {
      mode = "n";
      key = "<C-Right>";
      action = "<cmd>vertical resize +2<cr>";
      desc = "Increase Window Width";
    }
    # }}}
  ];
}
