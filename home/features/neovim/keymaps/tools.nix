_: {
  programs.nvf.settings.vim.keymaps = [
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
  ];
}
