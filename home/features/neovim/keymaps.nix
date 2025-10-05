{
  programs.nixvim = {
    globals.mapleader = " ";
    globals.localleader = " ";

    keymaps = [
      {
        mode = ["n" "x"];
        key = "j";
        action = "v:count == 0 ? 'gj' : 'j'";
        options = {
          expr = true;
          silent = true;
        };
      }
      {
        mode = ["n" "x"];
        key = "<Down>";
        action = "v:count == 0 ? 'gj' : 'j'";
        options = {
          expr = true;
          silent = true;
        };
      }
      {
        mode = ["n" "x"];
        key = "k";
        action = "v:count == 0 ? 'gk' : 'k'";
        options = {
          expr = true;
          silent = true;
        };
      }
      {
        mode = ["n" "x"];
        key = "<Up>";
        action = "v:count == 0 ? 'gk' : 'k'";
        options = {
          expr = true;
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<C-Up>";
        action = "<cmd>resize +2<cr>";
        options = {desc = "Increase Window Height";};
      }
      {
        mode = "n";
        key = "<C-Down>";
        action = "<cmd>resize -2<cr>";
        options = {desc = "Decrease Window Height";};
      }
      {
        mode = "n";
        key = "<C-Left>";
        action = "<cmd>vertical resize -2<cr>";
        options = {desc = "Decrease Window Width";};
      }
      {
        mode = "n";
        key = "<C-Right>";
        action = "<cmd>vertical resize +2<cr>";
        options = {desc = "Increase Window Width";};
      }
      {
        mode = "n";
        key = "<A-S-j>";
        action = "<cmd>m .+1<cr>==";
        options = {desc = "Move Line Down";};
      }
      {
        mode = "n";
        key = "<A-S-k>";
        action = "<cmd>m .-2<cr>==";
        options = {desc = "Move Line Up";};
      }
      {
        mode = "i";
        key = "<A-S-j>";
        action = "<esc><cmd>m .+1<cr>==gi";
        options = {desc = "Move Line Down";};
      }
      {
        mode = "i";
        key = "<A-S-k>";
        action = "<esc><cmd>m .-2<cr>==gi";
        options = {desc = "Move Line Up";};
      }
      {
        mode = "v";
        key = "<A-S-j>";
        action = ":m '>+1<cr>gv=gv";
        options = {desc = "Move Lines Down";};
      }
      {
        mode = "v";
        key = "<A-S-k>";
        action = ":m '<-2<cr>gv=gv";
        options = {desc = "Move Lines Up";};
      }
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
      {
        mode = "i";
        key = ";";
        action = ";<c-g>u";
      }
      {
        mode = ["i" "x" "n" "s"];
        key = "<C-s>";
        action = "<cmd>w<cr><esc>";
        options = {desc = "Save File";};
      }
      {
        mode = ["i" "n"];
        key = "<esc>";
        action = "<cmd>noh<cr><esc>";
        options = {desc = "Escape and Clear hlsearch";};
      }
      {
        mode = "n";
        key = "<leader>ur";
        action = "<Cmd>nohlsearch<Bar>diffupdate<Bar>normal! <C-L><CR>";
        options = {desc = "Redraw / Clear hlsearch / Diff Update";};
      }
      {
        mode = "n";
        key = "n";
        action = "'Nn'[v:searchforward].'zv'";
        options = {
          expr = true;
          desc = "Next Search Result";
        };
      }
      {
        mode = "x";
        key = "n";
        action = "'Nn'[v:searchforward]";
        options = {
          expr = true;
          desc = "Next Search Result";
        };
      }
      {
        mode = "o";
        key = "n";
        action = "'Nn'[v:searchforward]";
        options = {
          expr = true;
          desc = "Next Search Result";
        };
      }
      {
        mode = "n";
        key = "N";
        action = "'nN'[v:searchforward].'zv'";
        options = {
          expr = true;
          desc = "Prev Search Result";
        };
      }
      {
        mode = "x";
        key = "N";
        action = "'nN'[v:searchforward]";
        options = {
          expr = true;
          desc = "Prev Search Result";
        };
      }
      {
        mode = "o";
        key = "N";
        action = "'nN'[v:searchforward]";
        options = {
          expr = true;
          desc = "Prev Search Result";
        };
      }
      {
        mode = "n";
        key = "<leader>cd";
        action.__raw = "vim.diagnostic.open_float";
        options = {desc = "Line Diagnostics";};
      }
      {
        mode = "n";
        key = "]d";
        action.__raw = "function() vim.diagnostic.goto_next() end";
        options = {desc = "Next Diagnostic";};
      }
      {
        mode = "n";
        key = "[d";
        action.__raw = "function() vim.diagnostic.goto_prev() end";
        options = {desc = "Prev Diagnostic";};
      }
      {
        mode = "n";
        key = "]e";
        action.__raw = ''function() vim.diagnostic.goto_next({ severity = vim.diagnostic.severity.ERROR }) end'';
        options = {desc = "Next Error";};
      }
      {
        mode = "n";
        key = "[e";
        action.__raw = ''function() vim.diagnostic.goto_prev({ severity = vim.diagnostic.severity.ERROR }) end'';
        options = {desc = "Prev Error";};
      }
      {
        mode = "n";
        key = "]w";
        action.__raw = ''function() vim.diagnostic.goto_next({ severity = vim.diagnostic.severity.WARN }) end'';
        options = {desc = "Next Warning";};
      }
      {
        mode = "n";
        key = "[w";
        action.__raw = ''function() vim.diagnostic.goto_prev({ severity = vim.diagnostic.severity.WARN }) end'';
        options = {desc = "Prev Warning";};
      }
      {
        mode = "n";
        key = "<leader>qq";
        action = "<cmd>qa<cr>";
        options = {desc = "Quit All";};
      }
      {
        mode = "n";
        key = "<leader>ui";
        action.__raw = "vim.show_pos";
        options = {desc = "Inspect Pos";};
      }
      {
        mode = "t";
        key = "<esc><esc>";
        action = "<c-\\><c-n>";
        options = {desc = "Enter Normal Mode";};
      }
      {
        mode = "t";
        key = "<C-h>";
        action = "<cmd>wincmd h<cr>";
        options = {desc = "Go to Left Window";};
      }
      {
        mode = "t";
        key = "<C-j>";
        action = "<cmd>wincmd j<cr>";
        options = {desc = "Go to Lower Window";};
      }
      {
        mode = "t";
        key = "<C-k>";
        action = "<cmd>wincmd k<cr>";
        options = {desc = "Go to Upper Window";};
      }
      {
        mode = "t";
        key = "<C-l>";
        action = "<cmd>wincmd l<cr>";
        options = {desc = "Go to Right Window";};
      }
      {
        mode = "t";
        key = "<C-/>";
        action = "<cmd>close<cr>";
        options = {desc = "Hide Terminal";};
      }
      {
        mode = "n";
        key = "<leader>ww";
        action = "<C-W>p";
        options = {
          desc = "Other Window";
          remap = true;
        };
      }
      {
        mode = "n";
        key = "<leader>wd";
        action = "<C-W>c";
        options = {
          desc = "Delete Window";
          remap = true;
        };
      }
      {
        mode = "n";
        key = "<leader>w-";
        action = "<C-W>s";
        options = {
          desc = "Split Window Below";
          remap = true;
        };
      }
      {
        mode = "n";
        key = "<leader>w|";
        action = "<C-W>v";
        options = {
          desc = "Split Window Right";
          remap = true;
        };
      }
      {
        mode = "n";
        key = "<leader>-";
        action = "<C-W>s";
        options = {
          desc = "Split Window Below";
          remap = true;
        };
      }
      {
        mode = "n";
        key = "<leader>|";
        action = "<C-W>v";
        options = {
          desc = "Split Window Right";
          remap = true;
        };
      }
      {
        mode = "n";
        key = "<leader><tab>l";
        action = "<cmd>tablast<cr>";
        options = {desc = "Last Tab";};
      }
      {
        mode = "n";
        key = "<leader><tab>f";
        action = "<cmd>tabfirst<cr>";
        options = {desc = "First Tab";};
      }
      {
        mode = "n";
        key = "<leader><tab><tab>";
        action = "<cmd>tabnew<cr>";
        options = {desc = "New Tab";};
      }
      {
        mode = "n";
        key = "<leader><tab>]";
        action = "<cmd>tabnext<cr>";
        options = {desc = "Next Tab";};
      }
      {
        mode = "n";
        key = "<leader><tab>d";
        action = "<cmd>tabclose<cr>";
        options = {desc = "Close Tab";};
      }
      {
        mode = "n";
        key = "<leader><tab>[";
        action = "<cmd>tabprevious<cr>";
        options = {desc = "Previous Tab";};
      }
    ];
  };
}
