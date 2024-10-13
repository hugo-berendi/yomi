{...}: {
  programs.nixvim.plugins = {
    vimtex = {
      enable = true;
      settings = {
        view_method = "zathura";
      };
    };
    cmp-latex-symbols = {
      enable = true;
    };
  };
}
