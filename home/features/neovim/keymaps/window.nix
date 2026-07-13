{...}: {
  programs.nvf.settings.vim.keymaps = [
    # {{{ Window management
    {
      mode = "n";
      key = "<leader>ww";
      action = "<C-W>p";
      desc = "Other Window";
    }
    {
      mode = "n";
      key = "<leader>wd";
      action = "<C-W>c";
      desc = "Delete Window";
    }
    {
      mode = "n";
      key = "<leader>w-";
      action = "<C-W>s";
      desc = "Split Window Below";
    }
    {
      mode = "n";
      key = "<leader>w|";
      action = "<C-W>v";
      desc = "Split Window Right";
    }
    {
      mode = "n";
      key = "<leader>-";
      action = "<C-W>s";
      desc = "Split Window Below";
    }
    {
      mode = "n";
      key = "<leader>|";
      action = "<C-W>v";
      desc = "Split Window Right";
    }
    # }}}
  ];
}
