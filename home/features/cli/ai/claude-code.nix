{
  pkgs,
  lib,
  config,
  inputs,
  ...
}: let
  foundryResource = import ./foundry.nix;
  claudeCode = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;
  foundry = pkgs.writeShellApplication {
    name = "claude-foundry";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      key_file="${config.home.homeDirectory}/${foundryResource.keyFile}"
      if [[ ! -s "$key_file" ]]; then
        echo "Foundry API key missing: $key_file" >&2
        exit 1
      fi
      # Keep subscription and gateway credentials out of this invocation.
      unset ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL
      unset ANTHROPIC_FOUNDRY_AUTH_TOKEN ANTHROPIC_FOUNDRY_BASE_URL
      unset CLAUDE_CODE_USE_BEDROCK CLAUDE_CODE_USE_VERTEX
      export CLAUDE_CODE_USE_FOUNDRY=1
      export ANTHROPIC_FOUNDRY_RESOURCE=${foundryResource.resource}
      ANTHROPIC_FOUNDRY_API_KEY="$(cat "$key_file")"
      export ANTHROPIC_FOUNDRY_API_KEY
      export ANTHROPIC_MODEL=claude-opus-5-5
      # Only Opus is deployed here; aliases must not select absent deployments.
      export ANTHROPIC_DEFAULT_OPUS_MODEL="$ANTHROPIC_MODEL"
      export ANTHROPIC_DEFAULT_SONNET_MODEL="$ANTHROPIC_MODEL"
      export ANTHROPIC_DEFAULT_HAIKU_MODEL="$ANTHROPIC_MODEL"
      export ANTHROPIC_SMALL_FAST_MODEL="$ANTHROPIC_MODEL"
      exec ${lib.getExe claudeCode} "$@"
    '';
  };
  settingsFile = "${config.home.homeDirectory}/.claude/settings.json";
  # Keys enforced on every activation; everything else in the file stays Claude's.
  managedSettings = pkgs.writeText "claude-code-managed-settings.json" (builtins.toJSON {
    # No Co-Authored-By trailer on commits.
    attribution.commit = "";
  });
in {
  home.packages = [
    claudeCode
    foundry
  ];

  yomi.persistence.at.state.apps.claude-code = {
    directories = ["${config.home.homeDirectory}/.claude"];
    files = ["${config.home.homeDirectory}/.claude.json"];
  };

  # Merged rather than linked: Claude Code rewrites settings.json itself (/config,
  # /model), which a read-only store symlink would break.
  home.activation.claudeCodeSettings = lib.hm.dag.entryAfter ["writeBoundary"] ''
    current='{}'
    [ -s ${settingsFile} ] && current=$(cat ${settingsFile})
    merged=$(echo "$current" | ${lib.getExe pkgs.jq} -s '.[0] * .[1]' - ${managedSettings})
    run mkdir -p ${dirOf settingsFile}
    run ${pkgs.bash}/bin/bash -c 'printf "%s\n" "$1" > "$2"' _ "$merged" ${settingsFile}
  '';
}
