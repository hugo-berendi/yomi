{lib, ...}: {
  # Commenting is built into Neovim (gc/gcc) and buffers close through
  # Snacks.bufdelete, so mini.comment and mini.bufremove are not needed.
  programs.nvf.settings.vim.mini = {
    # F/c/o select whole functions, classes and blocks by treesitter,
    # using the queries nvim-treesitter-textobjects ships.
    ai = {
      enable = true;
      setupOpts.custom_textobjects = lib.generators.mkLuaInline ''
        (function()
          local ts = require("mini.ai").gen_spec.treesitter
          return {
            F = ts({ a = "@function.outer", i = "@function.inner" }),
            c = ts({ a = "@class.outer", i = "@class.inner" }),
            o = ts({
              a = { "@block.outer", "@conditional.outer", "@loop.outer" },
              i = { "@block.inner", "@conditional.inner", "@loop.inner" },
            }),
          }
        end)()
      '';
    };
    icons = {
      enable = true;
      setupOpts.style = "glyph";
    };
    pairs = {
      enable = true;
    };
    surround.enable = true;
  };
}
