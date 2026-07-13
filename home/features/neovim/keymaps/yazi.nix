{...}: {
  programs.nvf.settings.vim.keymaps = [
    # {{{ Yazi
    {
      mode = "n";
      key = "<leader>e";
      action = "<cmd>Yazi<cr>";
      desc = "File Manager";
    }
    # }}}
  ];
}
