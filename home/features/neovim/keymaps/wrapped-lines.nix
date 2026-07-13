{...}: {
  programs.nvf.settings.vim.keymaps = [
    # {{{ Better j/k for wrapped lines
    {
      mode = ["n" "x"];
      key = "j";
      action = "v:count == 0 ? 'gj' : 'j'";
      expr = true;
      silent = true;
    }
    {
      mode = ["n" "x"];
      key = "<Down>";
      action = "v:count == 0 ? 'gj' : 'j'";
      expr = true;
      silent = true;
    }
    {
      mode = ["n" "x"];
      key = "k";
      action = "v:count == 0 ? 'gk' : 'k'";
      expr = true;
      silent = true;
    }
    {
      mode = ["n" "x"];
      key = "<Up>";
      action = "v:count == 0 ? 'gk' : 'k'";
      expr = true;
      silent = true;
    }
    # }}}
  ];
}
