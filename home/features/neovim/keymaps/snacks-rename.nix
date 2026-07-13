{...}: {
  programs.nvf.settings.vim.keymaps = [
    # {{{ Snacks rename
    {
      mode = "n";
      key = "<leader>cR";
      action = "<cmd>lua Snacks.rename.rename_file()<cr>";
      desc = "Rename File";
    }
    # }}}
  ];
}
