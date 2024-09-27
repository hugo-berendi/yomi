{
  programs.nixvim = {
    plugins = {
      markview = {
        # Does not work as of 24.05, only in unstable
        enable = true;
        settings = {
          hybrid_modes = ["i" "v"];
          modes = ["n" "no"];
        };
      };
    };
  };
}
