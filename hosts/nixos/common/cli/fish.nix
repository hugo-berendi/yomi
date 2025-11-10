{
  programs.fish = {
    enable = true;
    vendor = {
      completions.enable = true;
      config.enable = true;
      functions.enable = true;
    };
  };
  environment.etc."usr/bin/fish" = {
    source = "/etc/profiles/per-user/hugob/bin/fish";
    mode = "0755";
  };
}
