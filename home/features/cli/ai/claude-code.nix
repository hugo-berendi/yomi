{
  pkgs,
  lib,
  config,
  inputs,
  ...
}: let
  foundryResource = import ./foundry.nix;
  models = config.yomi.ai.models.claude;
  claudeCode = import ./claude-code-package.nix {inherit inputs pkgs;};
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
      export ANTHROPIC_MODEL=${models.main}
      # Foundry deployment names, not Anthropic ids. Every alias must name a
      # deployment that exists, or subagents and background calls 404.
      # Foundry aliases go by family; yomi.ai.models names roles.
      export ANTHROPIC_DEFAULT_OPUS_MODEL=${models.main}
      export ANTHROPIC_DEFAULT_SONNET_MODEL=${models.review}
      export ANTHROPIC_DEFAULT_HAIKU_MODEL=${models.cheap}
      export ANTHROPIC_SMALL_FAST_MODEL="$ANTHROPIC_DEFAULT_HAIKU_MODEL"
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
    (((import ./subscription-proxy.nix).wrap pkgs).claude claudeCode)
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
