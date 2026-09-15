{
  pkgs,
  inputs,
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
        args = ["-y" "@modelcontextprotocol/server-filesystem@2026.8.31" "${config.home.homeDirectory}/projects"];
      };

      playwright = {
        command = "${pkgs.nodejs}/bin/npx";
        args = ["-y" "@executeautomation/playwright-mcp-server@1.0.12"];
      };

      nixos = {
        command = lib.getExe inputs.mcp-nixos.packages.${pkgs.stdenv.hostPlatform.system}.default;
        args = [];
      };

      deepwiki = {
        command = "${pkgs.nodejs}/bin/npx";
        args = ["-y" "deepwiki-mcp@0.0.6"];
      };

      sequential-thinking = {
        command = "${pkgs.nodejs}/bin/npx";
        args = ["-y" "@modelcontextprotocol/server-sequential-thinking@2026.8.31"];
      };

      memory = {
        command = "${pkgs.nodejs}/bin/npx";
        args = ["-y" "@modelcontextprotocol/server-memory@2026.8.31"];
      };
    }
    // optionalAttrs (config.sops.secrets ? "EXA_API_KEY") {
      exa = {
        command = "${pkgs.bash}/bin/bash";
        args = ["-c" "EXA_API_KEY=$(cat ${config.sops.secrets.EXA_API_KEY.path}) ${pkgs.nodejs}/bin/npx -y exa-mcp-server@3.4.1"];
      };
    }
    // optionalAttrs (config.sops.secrets ? "GITHUB_TOKEN") {
      github = {
        command = "${pkgs.bash}/bin/bash";
        args = ["-c" "GITHUB_PERSONAL_ACCESS_TOKEN=$(cat ${config.sops.secrets.GITHUB_TOKEN.path}) ${pkgs.nodejs}/bin/npx -y @modelcontextprotocol/server-github@2025.4.8"];
      };
    }
    // optionalAttrs (config.sops.secrets ? "SEARXNG_URL") {
      searxng = {
        command = "${pkgs.bash}/bin/bash";
        args = ["-c" "SEARXNG_URL=$(cat ${config.sops.secrets.SEARXNG_URL.path}) ${pkgs.nodejs}/bin/npx -y mcp-searxng@2.2.0"];
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
