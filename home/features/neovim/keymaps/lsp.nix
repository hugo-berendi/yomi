_: {
  programs.nvf.settings.vim.keymaps = [
    # {{{ Rename, format
    {
      mode = "n";
      key = "<leader>cr";
      action = ''function() return ":IncRename " .. vim.fn.expand("<cword>") end'';
      lua = true;
      expr = true;
      desc = "Rename Symbol";
    }
    {
      mode = ["n" "v"];
      key = "<leader>cf";
      action = ''function() require("conform").format({ lsp_format = "fallback" }) end'';
      lua = true;
      desc = "Format";
    }
    {
      mode = "n";
      key = "<leader>uf";
      action = "<cmd>FormatToggle<cr>";
      desc = "Toggle Format on Save";
    }
    {
      mode = "n";
      key = "<leader>uF";
      action = "<cmd>FormatToggle!<cr>";
      desc = "Toggle Format on Save (Buffer)";
    }
    # }}}
  ];
}
