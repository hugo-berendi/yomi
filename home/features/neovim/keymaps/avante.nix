{...}: {
  programs.nvf.settings.vim.keymaps = [
    # {{{ Avante AI
    {
      mode = ["n" "v"];
      key = "<leader>aa";
      action = "<cmd>AvanteAsk<cr>";
      desc = "Avante Ask";
    }
    {
      mode = "v";
      key = "<leader>ae";
      action = "<cmd>AvanteEdit<cr>";
      desc = "Avante Edit";
    }
    {
      mode = "n";
      key = "<leader>at";
      action = "<cmd>AvanteToggle<cr>";
      desc = "Avante Toggle";
    }
    {
      mode = "n";
      key = "<leader>ar";
      action = "<cmd>AvanteRefresh<cr>";
      desc = "Avante Refresh";
    }
    {
      mode = "n";
      key = "<leader>af";
      action = "<cmd>AvanteFocus<cr>";
      desc = "Avante Focus";
    }
    # }}}
  ];
}
