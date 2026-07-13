{...}: {
  programs.nvf.settings.vim.keymaps = [
    # {{{ Undo breakpoints
    {
      mode = "i";
      key = ";";
      action = ";<c-g>u";
    }
    {
      mode = "i";
      key = ".";
      action = ".<c-g>u";
    }
    # }}}
  ];
}
