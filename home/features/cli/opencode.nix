{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: {
  home.packages = with inputs.nix-ai-tools.packages.${pkgs.system}; [
    gemini-cli
    pkgs.nodejs
    pkgs.nix
    pkgs.bash
  ];
  programs.opencode = {
    enable = true;
    package = inputs.opencode-flake.packages.${pkgs.system}.default;

    settings = {
      provider = {
        ollama = {
          npm = "@ai-sdk/openai-compatible";
          name = "Ollama (local)";
          options = {
            baseURL = "http://inari.hugo-berendi.de:8440/v1";
          };
          models = {
            llama2 = {
              name = "Llama 2";
            };
            "qwen2.5:14b" = {
              name = "Qwen 2.5";
            };
          };
        };
      };
      mcp =
        {
          filesystem = {
            type = "local";
            enabled = true;
            command = ["${pkgs.nodejs}/bin/npx" "-y" "@modelcontextprotocol/server-filesystem" "${config.home.homeDirectory}/projects"];
          };

          "Astro docs" = {
            type = "local";
            enabled = true;
            command = ["${pkgs.nodejs}/bin/npx" "-y" "mcp-remote" "https://mcp.docs.astro.build/mcp"];
          };

          playwright = {
            type = "local";
            enabled = true;
            command = ["${pkgs.nodejs}/bin/npx" "-y" "@executeautomation/playwright-mcp-server"];
          };

          nixos = {
            type = "local";
            enabled = true;
            command = ["${pkgs.nix}/bin/nix" "run" "github:utensils/mcp-nixos" "--"];
          };

          deepwiki = {
            type = "local";
            enabled = true;
            command = ["${pkgs.nodejs}/bin/npx" "-y" "deepwiki-mcp"];
          };
        }
        // lib.optionalAttrs (config.sops.secrets ? "EXA_API_KEY") {
          exa = {
            type = "local";
            enabled = true;
            command = ["${pkgs.bash}/bin/bash" "-c" "EXA_API_KEY=$(cat ${config.sops.secrets.EXA_API_KEY.path}) ${pkgs.nodejs}/bin/npx -y exa-mcp-server"];
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

  sops.secrets = lib.mkIf (builtins.pathExists ./secrets.yaml) {
    GITHUB_TOKEN = {
      sopsFile = ./secrets.yaml;
    };
    SEARXNG_URL = {
      sopsFile = ./secrets.yaml;
    };
    EXA_API_KEY = {
      sopsFile = ./secrets.yaml;
    };
  };

  yomi.persistence.at.state.apps.opencode.directories = ["${config.home.homeDirectory}/.local/share/opencode"];
}
