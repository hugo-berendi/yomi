_: {
  programs.nvf.settings.vim.keymaps = [
    # {{{ Inspect
    {
      mode = "n";
      key = "<leader>ui";
      action = "<cmd>lua vim.show_pos()<cr>";
      desc = "Inspect Pos";
    }
    # }}}
  ];
}
