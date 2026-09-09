_: {
  programs.nvf.settings.vim.mini = {
    ai.enable = true;
    bufremove.enable = true;
    icons = {
      enable = true;
      setupOpts.style = "glyph";
    };
    comment = {
      enable = true;
      setupOpts.mappings = {
        comment = "gcc";
        comment_line = "gcc";
        comment_visual = "gc";
        textobject = "gcc";
      };
    };
    pairs = {
      enable = true;
    };
    surround.enable = true;
  };
}
