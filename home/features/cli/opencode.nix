{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: let
  githubTokenPath = lib.optionalString (config.sops.secrets ? "GITHUB_TOKEN") config.sops.secrets.GITHUB_TOKEN.path;
  searxngUrlPath = lib.optionalString (config.sops.secrets ? "SEARXNG_URL") config.sops.secrets.SEARXNG_URL.path;
in {
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

          playwright = {
            type = "local";
            enabled = true;
            command = ["${pkgs.nodejs}/bin/npx" "-y" "@executeautomation/playwright-mcp-server"];
          };

          "Astro docs" = {
            type = "local";
            enabled = true;
            command = ["${pkgs.nodejs}/bin/npx" "-y" "mcp-remote" "https://mcp.docs.astro.build/mcp"];
          };

          postgres = {
            type = "local";
            enabled = true;
            command = ["${pkgs.nodejs}/bin/npx" "-y" "@modelcontextprotocol/server-postgres" "postgresql://localhost/postgres"];
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
            command = ["${pkgs.nodejs}/bin/npx" "-y" "@modelcontextprotocol/server-github"];
            environment = {
              GITHUB_PERSONAL_ACCESS_TOKEN = githubTokenPath;
            };
          };
        }
        // lib.optionalAttrs (config.sops.secrets ? "SEARXNG_URL") {
          searxng = {
            type = "local";
            enabled = true;
            command = ["${pkgs.nodejs}/bin/npx" "-y" "mcp-searxng"];
            environment = {
              SEARXNG_URL = searxngUrlPath;
            };
          };
        };
    };
  };

  home.packages = [pkgs.nodejs];

  sops.secrets = lib.mkIf (builtins.pathExists ./secrets.yaml) {
    SEARXNG_URL = {
      sopsFile = ./secrets.yaml;
    };
  };

  yomi.persistence.at.state.apps.opencode.directories = ["${config.home.homeDirectory}/.local/share/opencode"];
}
