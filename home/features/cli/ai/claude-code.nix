{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: let
  cfg = config.yomi.ai.mcp;
  toClaudeMcp = name: value: {
    ${name} = {
      command = value.command;
      args = value.args;
    };
  };
  mcpServers = lib.foldl' (acc: name: acc // toClaudeMcp name cfg.${name}) {} (builtins.attrNames cfg);
  claudeConfig = {
    mcpServers = mcpServers;
  };
in {
  home.packages = [
    inputs.llm-agents.packages.${pkgs.system}.claude-code
  ];

  home.file.".claude.json".text = builtins.toJSON claudeConfig;

  yomi.persistence.at.state.apps.claude-code.directories = [
    "${config.home.homeDirectory}/.claude"
  ];
}
