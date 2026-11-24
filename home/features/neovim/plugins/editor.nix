{
  lib,
  pkgs,
  ...
}: {
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
        zen.enabled = true;
        dim.enabled = true;
        scratch.enabled = true;
        # Images and rendered LaTeX math inline, via the kitty graphics
        # protocol; inside tmux this needs allow-passthrough (cli/tmux).
        image = {
          enabled = true;
          doc = {
            inline = true;
            float = true;
          };
          math.enabled = true;
        };
      };
    };

    motion.flash-nvim.enable = true;

    # Loads a project's .envrc, so LSPs and formatters from its devshell are
    # on PATH instead of whatever the profile happens to carry.
    direnv.enable = true;
    # Worth having now that undo history persists (see ../default.nix).
    undotree.enable = true;
    grug-far-nvim.enable = true;
    diffview-nvim.enable = true;

    # Yank ring kept in shada, so it survives restarts too.
    yanky-nvim.enable = true;
  };

  # snacks.image converts through ImageMagick; math renders with the
  # pdflatex already on PATH for VimTeX.
  programs.nvf.settings.vim.extraPackages = [pkgs.imagemagick];

  # Neovim's own default. nvf's yanky assertion only accepts shada when
  # vim.options.shada is set explicitly.
  programs.nvf.settings.vim.options.shada = "!,'100,<50,s10,h";

  programs.nvf.settings.vim.utility = {
    # C-h/j/k/l and A-h/j/k/l cross from Neovim splits into tmux panes.
    # smart-splits marks the pane with @pane-is-vim for cli/tmux/tmux.conf.
    smart-splits = {
      enable = true;
      # The default <leader><leader>h.. would stall <leader><space>.
      keymaps = {
        swap_buf_left = "<leader>wH";
        swap_buf_down = "<leader>wJ";
        swap_buf_up = "<leader>wK";
        swap_buf_right = "<leader>wL";
      };
    };

    yazi-nvim = {
      enable = true;
      setupOpts = {
        open_for_directories = false;
      };
    };
  };

  # {{{ Sessions
  # tmux-continuum relaunches nvim in each restored pane; this reopens that
  # directory's buffers and splits. Only a bare `nvim` loads or records a
  # session, so a `git commit` editor never overwrites the project's one.
  programs.nvf.settings.vim.session.persisted = {
    enable = true;
    setupOpts = {
      autostart = false;
      use_git_branch = true;
    };
  };

  programs.nvf.settings.vim.autocmds = [
    {
      event = ["VimEnter"];
      nested = true;
      callback = lib.generators.mkLuaInline ''
        function()
          if vim.fn.argc() == 0 and not vim.g.started_with_stdin then
            local persisted = require("persisted")
            persisted.load()
            persisted.start()
          end
        end
      '';
      desc = "Restore and record the session for a bare nvim";
    }
    {
      event = ["StdinReadPre"];
      callback = lib.generators.mkLuaInline ''function() vim.g.started_with_stdin = true end'';
      desc = "Remember nvim was fed stdin";
    }
  ];
  # }}}

  programs.nvf.settings.vim.extraPlugins = {
    wakatime = {
      package = pkgs.vimPlugins.vim-wakatime;
    };
  };
}
