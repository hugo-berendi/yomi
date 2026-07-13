{...}: {
  programs.nvf.settings.vim.keymaps = [
    # {{{ Snacks notifications
    {
      mode = "n";
      key = "<leader>un";
      action = "<cmd>lua Snacks.notifier.hide()<cr>";
      desc = "Dismiss All Notifications";
    }
    {
      mode = "n";
      key = "<leader>nh";
      action = "<cmd>lua Snacks.notifier.show_history()<cr>";
      desc = "Notification History";
    }
    # }}}
  ];
}
