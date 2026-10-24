# codex from llm-agents.
{
  inputs,
  pkgs,
}: let
  inherit (inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}) codex;
in
  # Keep the existing in-process execution used by headless T3 sessions.
  # Updating the CLI must not replace a managed daemon beneath active clients.
  pkgs.symlinkJoin {
    name = "codex-${codex.version}";
    paths = [codex];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/codex --add-flags "-c features.daemon_auto_start=false"
    '';
    inherit (codex) version meta;
  }
