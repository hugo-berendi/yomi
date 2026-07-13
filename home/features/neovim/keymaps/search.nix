{...}: {
  programs.nvf.settings.vim.keymaps = [
    # {{{ Search navigation
    {
      mode = "n";
      key = "n";
      action = "'Nn'[v:searchforward].'zv'";
      expr = true;
      desc = "Next Search Result";
    }
    {
      mode = "x";
      key = "n";
      action = "'Nn'[v:searchforward]";
      expr = true;
      desc = "Next Search Result";
    }
    {
      mode = "o";
      key = "n";
      action = "'Nn'[v:searchforward]";
      expr = true;
      desc = "Next Search Result";
    }
    {
      mode = "n";
      key = "N";
      action = "'nN'[v:searchforward].'zv'";
      expr = true;
      desc = "Prev Search Result";
    }
    {
      mode = "x";
      key = "N";
      action = "'nN'[v:searchforward]";
      expr = true;
      desc = "Prev Search Result";
    }
    {
      mode = "o";
      key = "N";
      action = "'nN'[v:searchforward]";
      expr = true;
      desc = "Prev Search Result";
    }
    # }}}
  ];
}
