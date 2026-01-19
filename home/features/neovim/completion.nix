{pkgs, ...}: {
  programs.nvf.settings.vim.autocomplete = {
    blink-cmp = {
      enable = true;
      friendly-snippets.enable = true;
      setupOpts = {
        snippets.preset = "luasnip";
        appearance.nerd_font_variant = "mono";
        completion = {
          keyword.range = "prefix";
          documentation = {
            auto_show = true;
            auto_show_delay_ms = 200;
            window.border = "solid";
          };
          ghost_text.enabled = true;
          accept.auto_brackets.enabled = true;
          menu = {
            border = "solid";
            draw = {
              align_to = "none";
              columns = [
                {
                  __unkeyed-1 = "kind_icon";
                  __unkeyed-2 = "kind";
                  gap = 1;
                }
                {__unkeyed-1 = "label";}
                {__unkeyed-1 = "label_description";}
              ];
            };
          };
        };
        keymap = {
          preset = "default";
          "<Tab>" = ["select_next" "fallback"];
          "<S-Tab>" = ["select_prev" "fallback"];
          "<C-j>" = ["select_next" "fallback"];
          "<C-k>" = ["select_prev" "fallback"];
          "<C-b>" = ["scroll_documentation_up" "fallback"];
          "<C-f>" = ["scroll_documentation_down" "fallback"];
          "<C-e>" = ["hide" "fallback"];
          "<C-Space>" = ["show" "show_documentation" "hide_documentation"];
          "<CR>" = ["accept" "fallback"];
        };
        sources = {
          default = ["copilot" "lsp" "path" "snippets" "buffer"];
          providers = {
            copilot = {
              name = "copilot";
              module = "blink-cmp-copilot";
              score_offset = 100;
              async = true;
            };
            buffer = {
              min_keyword_length = 3;
              fallbacks = [];
            };
            path.min_keyword_length = 3;
            snippets.min_keyword_length = 3;
          };
        };
        signature = {
          enabled = true;
          window.border = "solid";
        };
      };
    };
  };

  programs.nvf.settings.vim.snippets.luasnip.enable = true;

  programs.nvf.settings.vim.extraPlugins = {
    blink-cmp-copilot = {
      package = pkgs.vimPlugins.blink-cmp-copilot;
    };
  };
}
