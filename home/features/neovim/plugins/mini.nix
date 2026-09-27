_: {
  programs.nvf.settings.vim.mini = {
    ai.enable = true;
    bufremove.enable = true;
    icons = {
      enable = true;
      setupOpts.style = "glyph";
    };
    # Upstream defaults: gc operator/visual/textobject, gcc for the line.
    comment.enable = true;
    pairs = {
      enable = true;
    };
    surround.enable = true;
  };
}
