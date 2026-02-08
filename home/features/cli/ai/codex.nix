{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: let
  cfg = config.yomi.ai.mcp;
  toCodexMcp = name: value: ''
    [mcp_servers.${lib.strings.escapeNixIdentifier name}]
    command = "${value.command}"
    args = ${builtins.toJSON value.args}
  '';
  mcpServersToml = lib.concatStringsSep "\n" (map (name: toCodexMcp name cfg.${name}) (builtins.attrNames cfg));
in {
  home.packages = [
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex
  ];

  xdg.configFile."codex/config.toml".text = mcpServersToml;

  yomi.persistence.at.state.apps.codex.directories = [
    "${config.xdg.configHome}/codex"
  ];
}
