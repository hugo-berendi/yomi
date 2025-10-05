{
  programs.nixvim.plugins.dressing = {
    settings = {
      input = {
        enabled = false;
      };
      select = {
        enabled = true;
        backend = [
          "builtin"
          "nui"
        ];
        builtin = {
          mappings = {
            "<Esc>" = "Close";
            "<C-c>" = "Close";
            "<CR>" = "Confirm";
          };
        };
      };
    };
  };
}
