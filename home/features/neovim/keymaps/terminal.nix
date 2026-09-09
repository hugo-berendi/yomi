_: {
  programs.nvf.settings.vim.keymaps = [
    # {{{ Terminal
    {
      mode = "t";
      key = "<esc><esc>";
      action = "<c-\\><c-n>";
      desc = "Enter Normal Mode";
    }
    {
      mode = "t";
      key = "<C-h>";
      action = "<cmd>wincmd h<cr>";
      desc = "Go to Left Window";
    }
    {
      mode = "t";
      key = "<C-j>";
      action = "<cmd>wincmd j<cr>";
      desc = "Go to Lower Window";
    }
    {
      mode = "t";
      key = "<C-k>";
      action = "<cmd>wincmd k<cr>";
      desc = "Go to Upper Window";
    }
    {
      mode = "t";
      key = "<C-l>";
      action = "<cmd>wincmd l<cr>";
      desc = "Go to Right Window";
    }
    {
      mode = "t";
      key = "<C-/>";
      action = "<cmd>close<cr>";
      desc = "Hide Terminal";
    }
    # }}}
  ];
}
