_: {
  programs.nvf.settings.vim.keymaps = [
    # {{{ Snacks terminal
    {
      mode = "n";
      key = "<c-/>";
      action = "<cmd>lua Snacks.terminal()<cr>";
      desc = "Toggle Terminal";
    }
    {
      mode = "n";
      key = "<c-_>";
      action = "<cmd>lua Snacks.terminal()<cr>";
      desc = "Toggle Terminal (which-key)";
    }
    {
      mode = "t";
      key = "<c-/>";
      action = "<cmd>close<cr>";
      desc = "Hide Terminal";
    }
    {
      mode = "t";
      key = "<c-_>";
      action = "<cmd>close<cr>";
      desc = "Hide Terminal (which-key)";
    }
    # }}}
  ];
}
