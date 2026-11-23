_: {
  programs.nvf.settings.vim.keymaps = [
    # {{{ Snacks pickers
    {
      mode = "n";
      key = "<leader><space>";
      action = "<cmd>lua Snacks.picker.files()<cr>";
      desc = "Find Files";
    }
    {
      mode = "n";
      key = "<leader>/";
      action = "<cmd>lua Snacks.picker.grep()<cr>";
      desc = "Grep";
    }
    {
      mode = "n";
      key = "<leader>:";
      action = "<cmd>lua Snacks.picker.command_history()<cr>";
      desc = "Command History";
    }
    {
      mode = "n";
      key = "<leader>,";
      action = "<cmd>lua Snacks.picker.buffers()<cr>";
      desc = "Buffers";
    }
    {
      mode = "n";
      key = "<leader>fb";
      action = "<cmd>lua Snacks.picker.buffers()<cr>";
      desc = "Buffers";
    }
    {
      mode = "n";
      key = "<leader>ff";
      action = "<cmd>lua Snacks.picker.files()<cr>";
      desc = "Find Files";
    }
    {
      mode = "n";
      key = "<leader>fg";
      action = "<cmd>lua Snacks.picker.grep()<cr>";
      desc = "Grep";
    }
    {
      mode = "n";
      key = "<leader>fR";
      action = "<cmd>lua Snacks.picker.resume()<cr>";
      desc = "Resume";
    }
    {
      mode = "n";
      key = "<leader>fr";
      action = "<cmd>lua Snacks.picker.recent()<cr>";
      desc = "Recent";
    }
    {
      mode = "n";
      key = "<C-p>";
      action = "<cmd>lua Snacks.picker.git_files()<cr>";
      desc = "Git Files";
    }
    {
      mode = "n";
      key = "<leader>gc";
      action = "<cmd>lua Snacks.picker.git_log()<cr>";
      desc = "Git Log";
    }
    {
      mode = "n";
      key = "<leader>gs";
      action = "<cmd>lua Snacks.picker.git_status()<cr>";
      desc = "Git Status";
    }
    {
      mode = "n";
      key = "<leader>sa";
      action = "<cmd>lua Snacks.picker.autocmds()<cr>";
      desc = "Autocmds";
    }
    {
      mode = "n";
      key = "<leader>sb";
      action = "<cmd>lua Snacks.picker.lines()<cr>";
      desc = "Buffer Lines";
    }
    {
      mode = "n";
      key = "<leader>sc";
      action = "<cmd>lua Snacks.picker.command_history()<cr>";
      desc = "Command History";
    }
    {
      mode = "n";
      key = "<leader>sC";
      action = "<cmd>lua Snacks.picker.commands()<cr>";
      desc = "Commands";
    }
    {
      mode = "n";
      key = "<leader>sd";
      action = "<cmd>lua Snacks.picker.diagnostics_buffer()<cr>";
      desc = "Document Diagnostics";
    }
    {
      mode = "n";
      key = "<leader>sD";
      action = "<cmd>lua Snacks.picker.diagnostics()<cr>";
      desc = "Workspace Diagnostics";
    }
    {
      mode = "n";
      key = "<leader>sh";
      action = "<cmd>lua Snacks.picker.help()<cr>";
      desc = "Help Pages";
    }
    {
      mode = "n";
      key = "<leader>sH";
      action = "<cmd>lua Snacks.picker.highlights()<cr>";
      desc = "Highlights";
    }
    {
      mode = "n";
      key = "<leader>sk";
      action = "<cmd>lua Snacks.picker.keymaps()<cr>";
      desc = "Keymaps";
    }
    {
      mode = "n";
      key = "<leader>sM";
      action = "<cmd>lua Snacks.picker.man()<cr>";
      desc = "Man Pages";
    }
    {
      mode = "n";
      key = "<leader>sm";
      action = "<cmd>lua Snacks.picker.marks()<cr>";
      desc = "Marks";
    }
    {
      mode = "n";
      key = "<leader>sR";
      action = "<cmd>lua Snacks.picker.resume()<cr>";
      desc = "Resume";
    }
    {
      mode = "n";
      key = "<leader>uC";
      action = "<cmd>lua Snacks.picker.colorschemes()<cr>";
      desc = "Colorscheme";
    }
    {
      mode = "n";
      key = "<leader>qp";
      action = "<cmd>lua Snacks.picker.projects()<cr>";
      desc = "Projects";
    }
    # }}}
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
    # {{{ Snacks buffer management
    {
      mode = "n";
      key = "<leader>bd";
      action = "<cmd>lua Snacks.bufdelete()<cr>";
      desc = "Delete Buffer";
    }
    {
      mode = "n";
      key = "<leader>bo";
      action = "<cmd>lua Snacks.bufdelete.other()<cr>";
      desc = "Delete Other Buffers";
    }
    # }}}
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
    # {{{ Snacks terminal
    {
      mode = "n";
      key = "<c-/>";
      action = "<cmd>lua Snacks.terminal()<cr>";
      desc = "Toggle Terminal";
    }
    {
      mode = "n";
      key = "<c-_>";
      action = "<cmd>lua Snacks.terminal()<cr>";
      desc = "Toggle Terminal (which-key)";
    }
    {
      mode = "t";
      key = "<c-/>";
      action = "<cmd>close<cr>";
      desc = "Hide Terminal";
    }
    {
      mode = "t";
      key = "<c-_>";
      action = "<cmd>close<cr>";
      desc = "Hide Terminal (which-key)";
    }
    # }}}
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
    # {{{ Snacks rename
    {
      mode = "n";
      key = "<leader>cR";
      action = "<cmd>lua Snacks.rename.rename_file()<cr>";
      desc = "Rename File";
    }
    # }}}
  ];
}
