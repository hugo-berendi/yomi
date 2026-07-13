{...}: {
  programs.nvf.settings.vim.keymaps = [
    # {{{ Move lines
    {
      mode = "n";
      key = "<A-S-j>";
      action = "<cmd>m .+1<cr>==";
      desc = "Move Line Down";
    }
    {
      mode = "n";
      key = "<A-S-k>";
      action = "<cmd>m .-2<cr>==";
      desc = "Move Line Up";
    }
    {
      mode = "i";
      key = "<A-S-j>";
      action = "<esc><cmd>m .+1<cr>==gi";
      desc = "Move Line Down";
    }
    {
      mode = "i";
      key = "<A-S-k>";
      action = "<esc><cmd>m .-2<cr>==gi";
      desc = "Move Line Up";
    }
    {
      mode = "v";
      key = "<A-S-j>";
      action = ":m '>+1<cr>gv=gv";
      desc = "Move Lines Down";
    }
    {
      mode = "v";
      key = "<A-S-k>";
      action = ":m '<-2<cr>gv=gv";
      desc = "Move Lines Up";
    }
    # }}}
  ];
}
