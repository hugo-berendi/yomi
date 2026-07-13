{...}: {
  programs.nvf.settings.vim.keymaps = [
    # {{{ Snacks buffer management
    {
      mode = "n";
      key = "<leader>bd";
      action = "<cmd>lua Snacks.bufdelete()<cr>";
      desc = "Delete Buffer";
    }
    {
      mode = "n";
      key = "<leader>bo";
      action = "<cmd>lua Snacks.bufdelete.other()<cr>";
      desc = "Delete Other Buffers";
    }
    # }}}
  ];
}
