{lib, ...}: {
  programs.nvf.settings.vim.keymaps = [
    # {{{ Better j/k for wrapped lines
    {
      mode = ["n" "x"];
      key = "j";
      action = "v:count == 0 ? 'gj' : 'j'";
      expr = true;
      silent = true;
    }
    {
      mode = ["n" "x"];
      key = "<Down>";
      action = "v:count == 0 ? 'gj' : 'j'";
      expr = true;
      silent = true;
    }
    {
      mode = ["n" "x"];
      key = "k";
      action = "v:count == 0 ? 'gk' : 'k'";
      expr = true;
      silent = true;
    }
    {
      mode = ["n" "x"];
      key = "<Up>";
      action = "v:count == 0 ? 'gk' : 'k'";
      expr = true;
      silent = true;
    }
    # }}}
    # {{{ Window resize
    {
      mode = "n";
      key = "<C-Up>";
      action = "<cmd>resize +2<cr>";
      desc = "Increase Window Height";
    }
    {
      mode = "n";
      key = "<C-Down>";
      action = "<cmd>resize -2<cr>";
      desc = "Decrease Window Height";
    }
    {
      mode = "n";
      key = "<C-Left>";
      action = "<cmd>vertical resize -2<cr>";
      desc = "Decrease Window Width";
    }
    {
      mode = "n";
      key = "<C-Right>";
      action = "<cmd>vertical resize +2<cr>";
      desc = "Increase Window Width";
    }
    # }}}
    # {{{ Move lines
    {
      mode = "n";
      key = "<A-S-j>";
      action = "<cmd>m .+1<cr>==";
      desc = "Move Line Down";
    }
    {
      mode = "n";
      key = "<A-S-k>";
      action = "<cmd>m .-2<cr>==";
      desc = "Move Line Up";
    }
    {
      mode = "i";
      key = "<A-S-j>";
      action = "<esc><cmd>m .+1<cr>==gi";
      desc = "Move Line Down";
    }
    {
      mode = "i";
      key = "<A-S-k>";
      action = "<esc><cmd>m .-2<cr>==gi";
      desc = "Move Line Up";
    }
    {
      mode = "v";
      key = "<A-S-j>";
      action = ":m '>+1<cr>gv=gv";
      desc = "Move Lines Down";
    }
    {
      mode = "v";
      key = "<A-S-k>";
      action = ":m '<-2<cr>gv=gv";
      desc = "Move Lines Up";
    }
    # }}}
    # {{{ Undo breakpoints
    {
      mode = "i";
      key = ";";
      action = ";<c-g>u";
    }
    {
      mode = "i";
      key = ".";
      action = ".<c-g>u";
    }
    # }}}
    # {{{ Save/Quit
    {
      mode = ["i" "x" "n" "s"];
      key = "<C-s>";
      action = "<cmd>w<cr><esc>";
      desc = "Save File";
    }
    {
      mode = ["i" "n"];
      key = "<esc>";
      action = "<cmd>noh<cr><esc>";
      desc = "Escape and Clear hlsearch";
    }
    {
      mode = "n";
      key = "<leader>ur";
      action = "<Cmd>nohlsearch<Bar>diffupdate<Bar>normal! <C-L><CR>";
      desc = "Redraw / Clear hlsearch / Diff Update";
    }
    {
      mode = "n";
      key = "<leader>qq";
      action = "<cmd>qa<cr>";
      desc = "Quit All";
    }
    # }}}
    # {{{ Search navigation
    {
      mode = "n";
      key = "n";
      action = "'Nn'[v:searchforward].'zv'";
      expr = true;
      desc = "Next Search Result";
    }
    {
      mode = "x";
      key = "n";
      action = "'Nn'[v:searchforward]";
      expr = true;
      desc = "Next Search Result";
    }
    {
      mode = "o";
      key = "n";
      action = "'Nn'[v:searchforward]";
      expr = true;
      desc = "Next Search Result";
    }
    {
      mode = "n";
      key = "N";
      action = "'nN'[v:searchforward].'zv'";
      expr = true;
      desc = "Prev Search Result";
    }
    {
      mode = "x";
      key = "N";
      action = "'nN'[v:searchforward]";
      expr = true;
      desc = "Prev Search Result";
    }
    {
      mode = "o";
      key = "N";
      action = "'nN'[v:searchforward]";
      expr = true;
      desc = "Prev Search Result";
    }
    # }}}
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
      key = "<leader>b";
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
      key = "<leader>fr";
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
      key = "<leader>fg";
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
    # {{{ Yazi
    {
      mode = "n";
      key = "<leader>e";
      action = "<cmd>Yazi<cr>";
      desc = "File Manager";
    }
    # }}}
  ];
}
