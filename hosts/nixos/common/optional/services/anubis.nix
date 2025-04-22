{pkgs, ...}: {
  services.anubis = {
    package = pkgs.anubis;
    defaultOptions = {
      enable = true;
      settings = {
        SERVE_ROBOTS_TXT = true;
      };
    };
  };
}
