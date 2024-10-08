{
  programs.nixvim.plugins.mini = {
    enable = true;
    mockDevIcons = true;
    modules = {
      icons = {
        style = "glyph";
      };
      comment = {
        mappings = {
          comment = "gcc";
          comment_line = "gcc";
          comment_visual = "gc";
          textobject = "gcc";
        };
      };
    };
  };
}
