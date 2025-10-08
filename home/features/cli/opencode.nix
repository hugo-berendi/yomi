{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: {
  programs.opencode = {
    enable = true;
    package = inputs.opencode-flake.packages.${pkgs.system}.default;

    settings = {
      mcp =
        {
          filesystem = {
            type = "local";
            enabled = true;
            command = ["${pkgs.nodejs}/bin/npx" "-y" "@modelcontextprotocol/server-filesystem" "${config.home.homeDirectory}/projects"];
          };

          git = {
            type = "local";
            enabled = true;
            command = ["${pkgs.nodejs}/bin/npx" "-y" "@modelcontextprotocol/server-git"];
          };

          "Astro docs" = {
            type = "local";
            enabled = true;
            command = ["${pkgs.nodejs}/bin/npx" "-y" "mcp-remote" "https://mcp.docs.astro.build/mcp"];
          };

          fetch = {
            type = "local";
            enabled = true;
            command = ["${pkgs.nodejs}/bin/npx" "-y" "@modelcontextprotocol/server-fetch"];
          };
        }
        // lib.optionalAttrs (config.sops.secrets ? "GITHUB_TOKEN") {
          github = {
            type = "local";
            enabled = true;
            command = ["${pkgs.bash}/bin/bash" "-c" "GITHUB_PERSONAL_ACCESS_TOKEN=$(cat ${config.sops.secrets.GITHUB_TOKEN.path}) ${pkgs.nodejs}/bin/npx -y @modelcontextprotocol/server-github"];
          };
        }
        // lib.optionalAttrs (config.sops.secrets ? "SEARXNG_URL") {
          searxng = {
            type = "local";
            enabled = true;
            command = ["${pkgs.bash}/bin/bash" "-c" "SEARXNG_URL=$(cat ${config.sops.secrets.SEARXNG_URL.path}) ${pkgs.nodejs}/bin/npx -y mcp-searxng"];
          };
        };
    };
  };

  home.packages = [pkgs.nodejs];

  sops.secrets = lib.mkIf (builtins.pathExists ./secrets.yaml) {
    GITHUB_TOKEN = {
      sopsFile = ./secrets.yaml;
    };
    SEARXNG_URL = {
      sopsFile = ./secrets.yaml;
    };
  };

  yomi.persistence.at.state.apps.opencode.directories = ["${config.home.homeDirectory}/.local/share/opencode"];
}
