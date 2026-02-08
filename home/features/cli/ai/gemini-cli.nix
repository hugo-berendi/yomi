{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: let
  cfg = config.yomi.ai.mcp;
  toGeminiMcp = name: value: {
    ${name} = {
      command = value.command;
      args = value.args;
    };
  };
  mcpServers = lib.foldl' (acc: name: acc // toGeminiMcp name cfg.${name}) {} (builtins.attrNames cfg);
  geminiConfig = {
    mcpServers = mcpServers;
  };
in {
  home.packages = [
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.gemini-cli
  ];

  xdg.configFile."gemini/settings.json".text = builtins.toJSON geminiConfig;

  yomi.persistence.at.state.apps.gemini-cli.directories = [
    "${config.xdg.configHome}/gemini"
  ];
}
