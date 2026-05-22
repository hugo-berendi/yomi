{
  pkgs,
  config,
  ...
}: let
  host = "git.amaterasu";
in {
  yomi.nginx.at.${host} = {};
  services.cgit."${config.yomi.nginx.at.${host}.host}" = {
    enable = true;
    package = pkgs.cgit-pink;
    scanPath = "/home/hugob/projects";
    group = "users";
    gitHttpBackend.enable = false; # I'll never clone local repos

    settings = {
      about-filter = "${pkgs.cgit-pink}/lib/cgit/filters/about-formatting.sh";
      commit-filter = "${pkgs.cgit-pink}/lib/cgit/filters/commit-links.sh";
      source-filter = "${pkgs.cgit-pink}/lib/cgit/filters/syntax-highlighting.py";
      enable-blame = true;
      enable-commit-graph = true;
      enable-follow-links = true;
      enable-log-filecount = false;
      enable-log-linecount = false;
      enable-remote-branches = false;
      enable-index-owner = false;
      robots = "nofollow";
      root-title = "hugo-berendi.git";
      root-desc = "my local repos -_-";
      readme = "README.md";
      section-from-path = 0;
      remove-suffix = true;
    };
  };
}
