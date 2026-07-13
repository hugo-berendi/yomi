{...}: {
  programs.nvf.settings.vim.keymaps = [
    # {{{ Diagnostics
    {
      mode = "n";
      key = "<leader>cd";
      action = "<cmd>lua vim.diagnostic.open_float()<cr>";
      desc = "Line Diagnostics";
    }
    {
      mode = "n";
      key = "]d";
      action = "<cmd>lua vim.diagnostic.goto_next()<cr>";
      desc = "Next Diagnostic";
    }
    {
      mode = "n";
      key = "[d";
      action = "<cmd>lua vim.diagnostic.goto_prev()<cr>";
      desc = "Prev Diagnostic";
    }
    {
      mode = "n";
      key = "]e";
      action = "<cmd>lua vim.diagnostic.goto_next({ severity = vim.diagnostic.severity.ERROR })<cr>";
      desc = "Next Error";
    }
    {
      mode = "n";
      key = "[e";
      action = "<cmd>lua vim.diagnostic.goto_prev({ severity = vim.diagnostic.severity.ERROR })<cr>";
      desc = "Prev Error";
    }
    {
      mode = "n";
      key = "]w";
      action = "<cmd>lua vim.diagnostic.goto_next({ severity = vim.diagnostic.severity.WARN })<cr>";
      desc = "Next Warning";
    }
    {
      mode = "n";
      key = "[w";
      action = "<cmd>lua vim.diagnostic.goto_prev({ severity = vim.diagnostic.severity.WARN })<cr>";
      desc = "Prev Warning";
    }
    # }}}
  ];
}
