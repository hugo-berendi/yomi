{
  pkgs,
  lib,
  config,
  inputs,
  ...
}: let
  settingsFile = "${config.home.homeDirectory}/.claude/settings.json";
  # Keys enforced on every activation; everything else in the file stays Claude's.
  managedSettings = pkgs.writeText "claude-code-managed-settings.json" (builtins.toJSON {
    # No Co-Authored-By trailer on commits.
    attribution.commit = "";
  });
in {
  home.packages = [
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
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
