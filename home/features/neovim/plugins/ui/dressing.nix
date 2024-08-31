{
  programs.nixvim.plugins.dressing = {
    settings = {
      input = {
        enabled = true;
        appings = {
          n = {
            "<Esc>" = "Close";
            "<CR>" = "Confirm";
          };
          i = {
            "<C-c>" = "Close";
            "<CR>" = "Confirm";
            "<Up>" = "HistoryPrev";
            "<Down>" = "HistoryNext";
          };
        };
      };
      select = {
        enabled = true;
        backend = [
          "telescope"
          "fzf_lua"
          "fzf"
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
