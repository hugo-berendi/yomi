_: {
  programs.nvf.settings.vim.autocmds = [
    {
      event = ["TextYankPost"];
      pattern = ["*"];
      callback = {
        _type = "lua-inline";
        expr = ''
          function()
            vim.highlight.on_yank()
          end
        '';
      };
      desc = "Highlight on yank";
    }
    {
      event = ["FileType"];
      pattern = ["help" "Startup" "startup" "Trouble" "trouble" "notify" "snacks_dashboard"];
      callback = {
        _type = "lua-inline";
        expr = ''
          function()
            vim.b.miniindentscope_disable = true
          end
        '';
      };
      desc = "Disable mini indentscope for certain filetypes";
    }
    {
      event = ["BufReadPost"];
      pattern = ["*"];
      callback = {
        _type = "lua-inline";
        expr = ''
          function()
            if
              vim.fn.line "'\"" > 1
              and vim.fn.line "'\"" <= vim.fn.line "$"
              and vim.bo.filetype ~= "commit"
              and vim.fn.index({ "xxd", "gitrebase" }, vim.bo.filetype) == -1
            then
              vim.cmd "normal! g`\""
            end
          end
        '';
      };
      desc = "Restore cursor position";
    }
    {
      event = ["FocusGained" "TermClose" "TermLeave"];
      pattern = ["*"];
      command = "checktime";
      desc = "Reload externally changed files";
    }
    {
      event = ["VimResized"];
      pattern = ["*"];
      command = "tabdo wincmd =";
      desc = "Balance windows after resizing";
    }
    {
      event = ["FileType"];
      pattern = ["gitcommit" "markdown" "tex"];
      callback = {
        _type = "lua-inline";
        expr = ''
          function()
            vim.opt_local.spell = true
            vim.opt_local.wrap = true
          end
        '';
      };
      desc = "Enable prose editing options";
    }
    {
      event = ["User"];
      pattern = ["VeryLazy"];
      callback = {
        _type = "lua-inline";
        expr = ''
          function()
            _G.dd = function(...)
              Snacks.debug.inspect(...)
            end
            _G.bt = function()
              Snacks.debug.backtrace()
            end
            vim.print = _G.dd
          end
        '';
      };
      desc = "Setup Snacks debug helpers";
    }
  ];
}
