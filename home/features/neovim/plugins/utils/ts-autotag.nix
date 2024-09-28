{
  programs.nixvim.plugins.ts-autotag = {
    enable = true;
    settings = {
      opts = {
        enable_close = true;
        enable_close_on_slash = true;
        enable_rename = true;
      };
    };
  };
}
