{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib) mkOption types optionalAttrs;
in {
  options.yomi.ai.mcp = mkOption {
    type = types.attrs;
    description = "Shared MCP server configurations for AI coding assistants";
    default = {};
  };

  options.yomi.ai.mcpRemote = mkOption {
    type = types.attrs;
    description = "Remote MCP server configurations (HTTP-based)";
    default = {};
  };

  config.yomi.ai.mcp =
    {
      filesystem = {
        command = "${pkgs.nodejs}/bin/npx";
        args = ["-y" "@modelcontextprotocol/server-filesystem" "${config.home.homeDirectory}/projects"];
      };

      playwright = {
        command = "${pkgs.nodejs}/bin/npx";
        args = ["-y" "@executeautomation/playwright-mcp-server"];
      };

      nixos = {
        command = "${pkgs.nix}/bin/nix";
        args = ["run" "github:utensils/mcp-nixos" "--"];
      };

      deepwiki = {
        command = "${pkgs.nodejs}/bin/npx";
        args = ["-y" "deepwiki-mcp"];
      };

      sequential-thinking = {
        command = "${pkgs.nodejs}/bin/npx";
        args = ["-y" "@modelcontextprotocol/server-sequential-thinking"];
      };

      memory = {
        command = "${pkgs.nodejs}/bin/npx";
        args = ["-y" "@modelcontextprotocol/server-memory"];
      };
    }
    // optionalAttrs (config.sops.secrets ? "EXA_API_KEY") {
      exa = {
        command = "${pkgs.bash}/bin/bash";
        args = ["-c" "EXA_API_KEY=$(cat ${config.sops.secrets.EXA_API_KEY.path}) ${pkgs.nodejs}/bin/npx -y exa-mcp-server"];
      };
    }
    // optionalAttrs (config.sops.secrets ? "GITHUB_TOKEN") {
      github = {
        command = "${pkgs.bash}/bin/bash";
        args = ["-c" "GITHUB_PERSONAL_ACCESS_TOKEN=$(cat ${config.sops.secrets.GITHUB_TOKEN.path}) ${pkgs.nodejs}/bin/npx -y @modelcontextprotocol/server-github"];
      };
    }
    // optionalAttrs (config.sops.secrets ? "SEARXNG_URL") {
      searxng = {
        command = "${pkgs.bash}/bin/bash";
        args = ["-c" "SEARXNG_URL=$(cat ${config.sops.secrets.SEARXNG_URL.path}) ${pkgs.nodejs}/bin/npx -y mcp-searxng"];
      };
    };

  config.yomi.ai.mcpRemote = {
    context7 = {
      url = "https://mcp.context7.com/mcp";
    };

    "Astro docs" = {
      url = "https://mcp.docs.astro.build/mcp";
    };
  };
}
