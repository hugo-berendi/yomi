_: {
  programs.nvf.settings.vim.keymaps = [
    # {{{ Snacks words
    {
      mode = "n";
      key = "]]";
      action = "<cmd>lua Snacks.words.jump(vim.v.count1)<cr>";
      desc = "Next Reference";
    }
    {
      mode = "n";
      key = "[[";
      action = "<cmd>lua Snacks.words.jump(-vim.v.count1)<cr>";
      desc = "Prev Reference";
    }
    # }}}
  ];
}
