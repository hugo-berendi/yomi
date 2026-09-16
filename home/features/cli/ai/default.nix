{
  pkgs,
  lib,
  ...
}: {
  # {{{ Imports
  imports = [
    ./mcp.nix
    ./opencode
    ./claude-code.nix
    ./codex.nix
    ./skills.nix
  ];
  # }}}
  # {{{ Packages
  home.packages = [
    pkgs.nodejs
    pkgs.nix
    pkgs.bash
  ];
  # }}}
  # {{{ Secrets
  sops.secrets = lib.mkIf (builtins.pathExists ./secrets.yaml) {
    SEARXNG_URL = {
      sopsFile = ./secrets.yaml;
    };
    EXA_API_KEY = {
      sopsFile = ./secrets.yaml;
    };
    IMMICH_API_KEY = {
      sopsFile = ./secrets.yaml;
    };
  };
  # }}}
}
