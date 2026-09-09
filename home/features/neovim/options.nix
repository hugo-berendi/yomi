{lib, ...}: {
  programs.nvf.settings.vim = {
    viAlias = true;
    vimAlias = true;
    debugMode.enable = false;

    globals = {
      mapleader = " ";
      maplocalleader = " ";
      neovide_padding_top = 6;
      neovide_padding_bottom = 6;
      neovide_padding_right = 12;
      neovide_padding_left = 12;
      neovide_theme = "auto";
      neovide_refresh_rate = 165;
      neovide_refresh_rate_idle = 5;
      neovide_fullscreen = false;
    };

    options = {
      number = true;
      relativenumber = true;
      clipboard = lib.mkForce "unnamedplus";
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

    clipboard = {
      enable = true;
      providers.wl-copy.enable = true;
    };

    luaConfigPre = ''
      vim.fn.sign_define("DiagnosticSignError", { text = " ", texthl = "DiagnosticError", linehl = "", numhl = "" })
      vim.fn.sign_define("DiagnosticSignWarn", { text = " ", texthl = "DiagnosticWarn", linehl = "", numhl = "" })
      vim.fn.sign_define("DiagnosticSignHint", { text = "󰌵", texthl = "DiagnosticHint", linehl = "", numhl = "" })
      vim.fn.sign_define("DiagnosticSignInfo", { text = " ", texthl = "DiagnosticInfo", linehl = "", numhl = "" })

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
      vim.lsp.handlers["textDocument/hover"] = function(err, result, ctx, opts)
        opts = vim.tbl_deep_extend("force", opts or {}, { border = _border })
        return vim.lsp.handlers.hover(err, result, ctx, opts)
      end
      vim.lsp.handlers["textDocument/signatureHelp"] = function(err, result, ctx, opts)
        opts = vim.tbl_deep_extend("force", opts or {}, { border = _border })
        return vim.lsp.handlers.signature_help(err, result, ctx, opts)
      end
      vim.diagnostic.config{ float = { border = _border } }

      local slow_format_filetypes = {}

      vim.api.nvim_create_user_command("FormatDisable", function(args)
        if args.bang then
          vim.b.disable_autoformat = true
        else
          vim.g.disable_autoformat = true
        end
      end, {
        desc = "Disable autoformat-on-save",
        bang = true,
      })
      vim.api.nvim_create_user_command("FormatEnable", function()
        vim.b.disable_autoformat = false
        vim.g.disable_autoformat = false
      end, {
        desc = "Re-enable autoformat-on-save",
      })
      vim.api.nvim_create_user_command("FormatToggle", function(args)
        if args.bang then
          vim.b.disable_autoformat = not vim.b.disable_autoformat
        else
          vim.g.disable_autoformat = not vim.g.disable_autoformat
        end
      end, {
        desc = "Toggle autoformat-on-save",
        bang = true,
      })
    '';

    luaConfigPost = ''
      vim.ui.input = Snacks.input
    '';
  };
}
