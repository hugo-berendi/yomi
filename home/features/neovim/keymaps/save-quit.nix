{...}: {
  programs.nvf.settings.vim.keymaps = [
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
  ];
}
