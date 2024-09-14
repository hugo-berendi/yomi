{
  programs.nixvim = {
    autoGroups = {
      highlight_yank = {};
      vim_enter = {};
      indentscope = {};
      restore_cursor = {};
      autosave = {};
    };

    autoCmd = [
      {
        group = "highlight_yank";
        event = ["TextYankPost"];
        pattern = "*";
        callback = {
          __raw = ''
            function()
              vim.highlight.on_yank()
            end
          '';
        };
      }
      {
        group = "indentscope";
        event = ["FileType"];
        pattern = [
          "help"
          "Startup"
          "startup"
          "neo-tree"
          "Trouble"
          "trouble"
          "notify"
        ];
        callback = {
          __raw = ''
            function()
              vim.b.miniindentscope_disable = true
            end
          '';
        };
      }
      ## from NVChad https://nvchad.com/docs/recipes (this autocmd will restore the cursor position when opening a file)
      {
        group = "restore_cursor";
        event = ["BufReadPost"];
        pattern = "*";
        callback = {
          __raw = ''
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
      }
      # {
      #   group = "autosave";
      #   event = ["TextChangedI"];
      #   pattern = "*";
      #   callback = {
      #     __raw =
      #       /*
      #       lua
      #       */
      #       ''
      #         function()
      #           -- Define a set of filetypes to be checked
      #           local excluded_filetypes = {
      #             ["help"] = true,
      #             ["Startup"] = true,
      #             ["startup"] = true,
      #             ["neo-tree"] = true,
      #             ["Trouble"] = true,
      #             ["trouble"] = true,
      #             ["notify"] = true,
      #             ["Telescope"] = true,
      #             ["telescope"] = true,
      #           }

      #           -- Check if the current filetype is in the excluded set
      #           if excluded_filetypes[vim.bo.filetype] then
      #             return
      #           end

      #           -- execute command
      #           vim.cmd 'silent write'
      #         end
      #       '';
      #   };
      # }
    ];
  };
}
