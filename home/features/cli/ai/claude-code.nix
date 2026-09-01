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
  claudeJson = "${config.home.homeDirectory}/.claude.json";
in {
  home.packages = [
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
  ];

  # ~/.claude.json also holds Claude Code's OAuth/account state, so it can't
  # be managed wholesale via home.file (that would overwrite auth on every
  # activation) - merge just the mcpServers key into the persisted file.
  #home.activation.claudeMcpServers = lib.hm.dag.entryAfter ["writeBoundary"] ''
  #   mcpServers='${builtins.toJSON mcpServers}'
  #
  #   if [[ -v DRY_RUN ]]; then
  #     echo "Would merge mcpServers into ${claudeJson}"
  #   else
  #     [[ -s "${claudeJson}" ]] || echo '{}' > "${claudeJson}"
  #     ${lib.getExe pkgs.jq} --argjson mcpServers "$mcpServers" '.mcpServers = $mcpServers' "${claudeJson}" > "${claudeJson}.tmp"
  #     mv "${claudeJson}.tmp" "${claudeJson}"
  #   fi
  # '';

  yomi.persistence.at.state.apps.claude-code = {
    directories = ["${config.home.homeDirectory}/.claude"];
    # files = [claudeJson];
  };
}
