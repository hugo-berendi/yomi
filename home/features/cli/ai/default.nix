{
  pkgs,
  config,
  lib,
  ...
}: {
  # {{{ Imports
  imports = [
    ./mcp.nix
    ./opencode.nix
    ./claude-code.nix
    ./codex.nix
    # TODO: Re-enable when llm-agents updates gemini-cli hash
    # ./gemini-cli.nix
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
    # TODO: Add these secrets to secrets.yaml for API authentication
    # ANTHROPIC_API_KEY = {
    #   sopsFile = ./secrets.yaml;
    # };
    # OPENAI_API_KEY = {
    #   sopsFile = ./secrets.yaml;
    # };
    # GEMINI_API_KEY = {
    #   sopsFile = ./secrets.yaml;
    # };
  };
  # }}}
}
