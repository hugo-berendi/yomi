_: {
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
  ];
}
