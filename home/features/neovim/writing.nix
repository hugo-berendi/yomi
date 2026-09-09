{pkgs, ...}: {
  programs.nvf.settings.vim = {
    globals = {
      vimtex_compiler_method = "latexmk";
      vimtex_compiler_latexmk = {
        aux_dir = ".build";
        out_dir = ".build";
        callback = 1;
        continuous = 1;
        executable = "latexmk";
        options = [
          "-pdf"
          "-verbose"
          "-file-line-error"
          "-synctex=1"
          "-interaction=nonstopmode"
        ];
      };
      vimtex_complete_enabled = 1;
      vimtex_quickfix_mode = 2;
      vimtex_syntax_conceal_disable = 1;
      vimtex_view_method = "zathura";
    };

    extraPlugins.vimtex.package = pkgs.vimPlugins.vimtex;

    keymaps = [
      {
        mode = "n";
        key = "<leader>lc";
        action = "<cmd>VimtexCompile<cr>";
        desc = "Compile LaTeX";
      }
      {
        mode = "n";
        key = "<leader>lv";
        action = "<cmd>VimtexView<cr>";
        desc = "View PDF";
      }
      {
        mode = "n";
        key = "<leader>le";
        action = "<cmd>VimtexErrors<cr>";
        desc = "LaTeX Errors";
      }
      {
        mode = "n";
        key = "<leader>lt";
        action = "<cmd>VimtexTocToggle<cr>";
        desc = "LaTeX Table of Contents";
      }
      {
        mode = "n";
        key = "<leader>lk";
        action = "<cmd>VimtexStop<cr>";
        desc = "Stop LaTeX Compiler";
      }
      {
        mode = "n";
        key = "<leader>lK";
        action = "<cmd>VimtexClean<cr>";
        desc = "Clean LaTeX Build";
      }
    ];

    autocmds = [
      {
        event = ["User"];
        pattern = ["VimtexEventInitPost"];
        callback = {
          _type = "lua-inline";
          expr = ''
            function()
              vim.cmd("VimtexCompile")
            end
          '';
        };
        desc = "Start continuous LaTeX compilation";
      }
    ];
  };
}
