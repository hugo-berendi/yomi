# codex from llm-agents.
{
  inputs,
  pkgs,
}: let
  inherit (inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}) codex;
in
  # 0.159 starts a background app-server daemon by default, and the daemon
  # needs a "complete local package" (codex-package.json beside bin/codex) to
  # copy into ~/.codex/packages. A Nix build has none, so every interactive
  # start died with "this CLI has no complete local package" (still true of
  # llm-agents' 0.159.2). Turn the auto-start off; codex then runs in-process
  # as before 0.159. Wrapped here rather than in postFixup, which would
  # rebuild codex from source.
  pkgs.symlinkJoin {
    name = "codex-${codex.version}";
    paths = [codex];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/codex --add-flags "-c features.daemon_auto_start=false"
    '';
    inherit (codex) version meta;
  }
