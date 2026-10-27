_: {
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
      action = "<cmd>lua vim.diagnostic.jump({ count = 1 })<cr>";
      desc = "Next Diagnostic";
    }
    {
      mode = "n";
      key = "[d";
      action = "<cmd>lua vim.diagnostic.jump({ count = -1 })<cr>";
      desc = "Prev Diagnostic";
    }
    {
      mode = "n";
      key = "]e";
      action = "<cmd>lua vim.diagnostic.jump({ count = 1, severity = vim.diagnostic.severity.ERROR })<cr>";
      desc = "Next Error";
    }
    {
      mode = "n";
      key = "[e";
      action = "<cmd>lua vim.diagnostic.jump({ count = -1, severity = vim.diagnostic.severity.ERROR })<cr>";
      desc = "Prev Error";
    }
    {
      mode = "n";
      key = "]w";
      action = "<cmd>lua vim.diagnostic.jump({ count = 1, severity = vim.diagnostic.severity.WARN })<cr>";
      desc = "Next Warning";
    }
    {
      mode = "n";
      key = "[w";
      action = "<cmd>lua vim.diagnostic.jump({ count = -1, severity = vim.diagnostic.severity.WARN })<cr>";
      desc = "Prev Warning";
    }
    # }}}
    # {{{ Inspect
    {
      mode = "n";
      key = "<leader>ui";
      action = "<cmd>lua vim.show_pos()<cr>";
      desc = "Inspect Pos";
    }
    # }}}
    # {{{ Terminal
    {
      mode = "t";
      key = "<esc><esc>";
      action = "<c-\\><c-n>";
      desc = "Enter Normal Mode";
    }
    {
      mode = "t";
      key = "<C-h>";
      action = "<cmd>wincmd h<cr>";
      desc = "Go to Left Window";
    }
    {
      mode = "t";
      key = "<C-j>";
      action = "<cmd>wincmd j<cr>";
      desc = "Go to Lower Window";
    }
    {
      mode = "t";
      key = "<C-k>";
      action = "<cmd>wincmd k<cr>";
      desc = "Go to Upper Window";
    }
    {
      mode = "t";
      key = "<C-l>";
      action = "<cmd>wincmd l<cr>";
      desc = "Go to Right Window";
    }
    {
      mode = "t";
      key = "<C-/>";
      action = "<cmd>close<cr>";
      desc = "Hide Terminal";
    }
    # }}}
    # {{{ Window management
    {
      mode = "n";
      key = "<leader>ww";
      action = "<C-W>p";
      desc = "Other Window";
    }
    {
      mode = "n";
      key = "<leader>wd";
      action = "<C-W>c";
      desc = "Delete Window";
    }
    {
      mode = "n";
      key = "<leader>w-";
      action = "<C-W>s";
      desc = "Split Window Below";
    }
    {
      mode = "n";
      key = "<leader>w|";
      action = "<C-W>v";
      desc = "Split Window Right";
    }
    {
      mode = "n";
      key = "<leader>-";
      action = "<C-W>s";
      desc = "Split Window Below";
    }
    {
      mode = "n";
      key = "<leader>|";
      action = "<C-W>v";
      desc = "Split Window Right";
    }
    # }}}
    # {{{ Tabs
    {
      mode = "n";
      key = "<leader><tab>l";
      action = "<cmd>tablast<cr>";
      desc = "Last Tab";
    }
    {
      mode = "n";
      key = "<leader><tab>f";
      action = "<cmd>tabfirst<cr>";
      desc = "First Tab";
    }
    {
      mode = "n";
      key = "<leader><tab><tab>";
      action = "<cmd>tabnew<cr>";
      desc = "New Tab";
    }
    {
      mode = "n";
      key = "<leader><tab>]";
      action = "<cmd>tabnext<cr>";
      desc = "Next Tab";
    }
    {
      mode = "n";
      key = "<leader><tab>d";
      action = "<cmd>tabclose<cr>";
      desc = "Close Tab";
    }
    {
      mode = "n";
      key = "<leader><tab>[";
      action = "<cmd>tabprevious<cr>";
      desc = "Previous Tab";
    }
    # }}}
  ];
}
