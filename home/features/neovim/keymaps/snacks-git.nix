_: {
  programs.nvf.settings.vim.keymaps = [
    # {{{ Snacks git
    {
      mode = "n";
      key = "<leader>gg";
      action = "<cmd>lua Snacks.lazygit()<cr>";
      desc = "Lazygit";
    }
    {
      mode = "n";
      key = "<leader>gb";
      action = "<cmd>lua Snacks.git.blame_line()<cr>";
      desc = "Git Blame Line";
    }
    {
      mode = "n";
      key = "<leader>gB";
      action = "<cmd>lua Snacks.gitbrowse()<cr>";
      desc = "Git Browse";
    }
    {
      mode = "n";
      key = "<leader>gf";
      action = "<cmd>lua Snacks.lazygit.log_file()<cr>";
      desc = "Lazygit Current File History";
    }
    {
      mode = "n";
      key = "<leader>gl";
      action = "<cmd>lua Snacks.lazygit.log()<cr>";
      desc = "Lazygit Log";
    }
    # }}}
  ];
}
