{lib, ...}: let
  inherit (lib.generators) mkLuaInline;
in {
  programs.nvf.settings.vim = {
    # {{{ blink.cmp
    autocomplete.blink-cmp = {
      enable = true;
      # Expanded by blink's native vim.snippet backend; luasnip only earns
      # its place with hand-written Lua snippets, and there are none.
      friendly-snippets.enable = true;

      mappings = {
        complete = "<C-Space>";
        confirm = "<CR>";
        next = "<Tab>";
        previous = "<S-Tab>";
        close = "<C-e>";
        scrollDocsUp = "<C-b>";
        scrollDocsDown = "<C-f>";
      };

      sourcePlugins = {
        spell.enable = true;
        emoji.enable = true;
      };

      setupOpts = {
        # nixpkgs builds the Rust matcher: typo-tolerant, frecency-ranked.
        fuzzy.implementation = "prefer_rust_with_warning";

        # nvf fills sources.default itself and lists concatenate, so leave it
        # alone; filetype-specific sources go in per_filetype.
        # VimTeX sets omnifunc on tex buffers; blink's built-in omni source
        # reads it, so no cmp-vimtex/blink.compat bridge is needed.
        sources.per_filetype.tex = mkLuaInline ''{ inherit_defaults = true, "omni" }'';
        sources.providers = {
          # autocmds.nix turns spell on for prose filetypes only.
          spell.opts.enable_in_context = mkLuaInline ''
            function() return vim.wo.spell end
          '';
          emoji.enabled = mkLuaInline ''
            function() return vim.tbl_contains({ "gitcommit", "markdown" }, vim.bo.filetype) end
          '';
          lsp.score_offset = 5;
          buffer.min_keyword_length = 3;
        };

        completion = {
          # Select without inserting, so typing on keeps going.
          list.selection = {
            preselect = true;
            auto_insert = false;
          };
          accept.auto_brackets.enabled = true;
          documentation = {
            auto_show = true;
            auto_show_delay_ms = 200;
            window.border = "rounded";
          };
          # Inline preview of the selected item.
          ghost_text.enabled = true;
          menu = {
            border = "rounded";
            draw = {
              columns = mkLuaInline ''{ { "kind_icon" }, { "label", gap = 1 } }'';
              # Labels highlighted as real code by colorful-menu.
              components.label = {
                text = mkLuaInline ''
                  function(ctx) return require("colorful-menu").blink_components_text(ctx) end
                '';
                highlight = mkLuaInline ''
                  function(ctx) return require("colorful-menu").blink_components_highlight(ctx) end
                '';
              };
            };
          };
        };

        signature = {
          enabled = true;
          window.border = "rounded";
        };

        cmdline = {
          enabled = true;
          completion = {
            menu.auto_show = true;
            list.selection.preselect = false;
          };
        };
      };
    };

    ui.colorful-menu-nvim.enable = true;
    # }}}
  };
}
