{ ...}: {
  programs.nixvim = {
    extraConfigLuaPre =
      # lua
      ''
        vim.fn.sign_define("diagnosticsignerror", { text = " ", texthl = "diagnosticerror", linehl = "", numhl = "" })
        vim.fn.sign_define("diagnosticsignwarn", { text = " ", texthl = "diagnosticwarn", linehl = "", numhl = "" })
        vim.fn.sign_define("diagnosticsignhint", { text = "󰌵", texthl = "diagnostichint", linehl = "", numhl = "" })
        vim.fn.sign_define("diagnosticsigninfo", { text = " ", texthl = "diagnosticinfo", linehl = "", numhl = "" })
        
        vim.opt.fillchars = {
          fold = " ",
          foldsep = " ",
          diff = "╱",
          eob = " ",
        }
        
        vim.opt.listchars = {
          tab = ">>>",
          trail = "·",
          precedes = "←",
          extends = "→",
          eol = "↲",
          nbsp = "␣",
        }

        local _border = "rounded"
        vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = _border })
        vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, { border = _border })
        vim.diagnostic.config{ float = { border = _border } }
        require('lspconfig.ui.windows').default_options = { border = _border }
      '';

    clipboard = {
      providers.wl-copy.enable = true;
    };

    globals = {
      neovide_padding_top = 6;
      neovide_padding_bottom = 6;
      neovide_padding_right = 12;
      neovide_padding_left = 12;
      neovide_theme = "auto";
      neovide_refresh_rate = 165;
      neovide_refresh_rate_idle = 5;
      neovide_fullscreen = false;
    };

    opts = {
      number = true;
      relativenumber = true;
      clipboard = "unnamedplus";
      tabstop = 2;
      softtabstop = 2;
      showtabline = 2;
      expandtab = true;
      smartindent = true;
      shiftwidth = 2;
      breakindent = true;
      cursorline = true;
      scrolloff = 8;
      mouse = "a";
      foldmethod = "manual";
      foldenable = false;
      linebreak = true;
      spell = false;
      swapfile = false;
      timeoutlen = 300;
      termguicolors = true;
      showmode = false;
      splitbelow = true;
      splitkeep = "screen";
      splitright = true;
      cmdheight = 0;
      undofile = true;
      undolevels = 10000;
      updatetime = 200;
      signcolumn = "yes";
      completeopt = "menu,menuone,noselect";
      conceallevel = 2;
      confirm = true;
      inccommand = "nosplit";
      laststatus = 3;
      list = true;
      pumblend = 10;
      pumheight = 10;
      sessionoptions = "buffers,curdir,tabpages,winsize,help,globals,skiprtp,folds";
      shiftround = true;
      shortmess = "filnxtToOFWIcC";
      virtualedit = "block";
      winminwidth = 5;
      wrap = false;
    };
  };
}
