{
  programs.nixvim.plugins = {
    mini = {
      modules.icons = {
        style = "glyph";
      };
      mockDevIcons = true;
    };
  };
}
