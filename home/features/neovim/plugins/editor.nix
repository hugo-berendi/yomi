{pkgs, ...}: {
  programs.nvf.settings.vim.utility = {
    snacks-nvim = {
      enable = true;
      setupOpts = {
        bigfile.enabled = true;
        dashboard = {
          enabled = true;
          preset.header = ''
                /\_____/\
               /  o   o  \
              ( ==  ^  == )
               )         (
              (           )
             ( (  )   (  ) )
            (__(__)___(__)__)
          '';
          sections = [
            {section = "header";}
            {
              section = "keys";
              gap = 1;
              padding = 1;
            }
            {
              pane = 2;
              icon = " ";
              title = "Recent Files";
              section = "recent_files";
              indent = 2;
              padding = 1;
            }
            {
              pane = 2;
              icon = " ";
              title = "Projects";
              section = "projects";
              indent = 2;
              padding = 1;
            }
          ];
        };
        indent = {
          enabled = true;
          indent.char = "│";
          scope.enabled = true;
        };
        input.enabled = true;
        win = {
          enabled = true;
          style = "float";
          border = "rounded";
        };
        notifier = {
          enabled = true;
          timeout = 3000;
        };
        picker = {
          enabled = true;
          win.input.keys = {
            "<C-j>" = ["list_down" {mode = ["i" "n"];}];
            "<C-k>" = ["list_up" {mode = ["i" "n"];}];
          };
        };
        quickfile.enabled = true;
        scroll.enabled = true;
        statuscolumn.enabled = true;
        terminal = {
          enabled = true;
          shell = "fish";
          win = {
            style = "terminal";
            height = 0.3;
          };
        };
        toggle.enabled = true;
        words.enabled = true;
      };
    };

    motion.flash-nvim.enable = true;

    yazi-nvim = {
      enable = true;
      setupOpts = {
        open_for_directories = false;
      };
    };
  };

  programs.nvf.settings.vim.extraPlugins = {
    wakatime = {
      package = pkgs.vimPlugins.vim-wakatime;
    };
  };
}
