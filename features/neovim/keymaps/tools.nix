_: {
  programs.nvf.settings.vim.keymaps = [
    # {{{ Yazi
    {
      mode = "n";
      key = "<leader>e";
      action = "<cmd>Yazi<cr>";
      desc = "File Manager";
    }
    # }}}
    # {{{ Undotree, grug-far, diffview
    {
      mode = "n";
      key = "<leader>U";
      action = "<cmd>UndotreeToggle<cr>";
      desc = "Undo Tree";
    }
    {
      mode = ["n" "v"];
      key = "<leader>sr";
      action = "<cmd>GrugFar<cr>";
      desc = "Search and Replace";
    }
    {
      mode = "n";
      key = "<leader>gd";
      action = "<cmd>DiffviewOpen<cr>";
      desc = "Diff Working Tree";
    }
    {
      mode = "n";
      key = "<leader>gD";
      action = "<cmd>DiffviewFileHistory %<cr>";
      desc = "Diff File History";
    }
    # }}}
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
