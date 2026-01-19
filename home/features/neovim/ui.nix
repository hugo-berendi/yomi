{config, ...}: {
  programs.nvf.settings.vim = {
    theme = {
      enable = true;
      name = "base16";
      base16-colors = {
        inherit
          (config.lib.stylix.colors.withHashtag)
          base00
          base01
          base02
          base03
          base04
          base05
          base06
          base07
          base08
          base09
          base0A
          base0B
          base0C
          base0D
          base0E
          base0F
          ;
      };
      transparent = true;
    };

    statusline.lualine = {
      enable = true;
      theme = "auto";
    };

    binds.whichKey.enable = true;

    ui = {
      colorizer.enable = true;
      noice = {
        enable = true;
        setupOpts = {
          lsp = {
            override = {
              "vim.lsp.util.convert_input_to_markdown_lines" = true;
              "vim.lsp.util.stylize_markdown" = true;
            };
            signature.enabled = false;
          };
          presets = {
            bottom_search = true;
            command_palette = true;
            long_message_to_split = true;
            inc_rename = false;
            lsp_doc_border = true;
          };
          routes = [
            {
              filter = {
                event = "msg_show";
                kind = "";
                find = "written";
              };
              opts.skip = true;
            }
            {
              filter = {
                event = "msg_show";
                kind = "";
                find = "yanked";
              };
              opts.skip = true;
            }
          ];
        };
      };
    };

    visuals = {
      rainbow-delimiters.enable = true;
    };

    notes.todo-comments.enable = true;
  };
}
