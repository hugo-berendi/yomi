# codex from llm-agents, bumped ahead of it. Drop the override once
# https://github.com/numtide/llm-agents.nix/pull/10062 (0.158.0 -> 0.159.1)
# lands; the hashes are taken from that PR.
{
  inputs,
  pkgs,
}: let
  codex = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex.override {
    version = "0.159.1";
    hash = "sha256-74sN8GM4W+u8bMxOenSp9tmIDqAtrABCmU5J8IsqZWA=";
    cargoVendor.cargoHash = "sha256-3X4gmzAZG10DDcI667k9Zf+r3IvzeAAWD1NbTdQZyGY=";
  };
in
  # 0.159 starts a background app-server daemon by default, and the daemon
  # needs a "complete local package" (codex-package.json beside bin/codex) to
  # copy into ~/.codex/packages. A Nix build has none, so every interactive
  # start died with "this CLI has no complete local package". Turn the
  # auto-start off; codex then runs in-process as before 0.159. Wrapped here
  # rather than in postFixup, which would rebuild codex from source.
  pkgs.symlinkJoin {
    name = "codex-${codex.version}";
    paths = [codex];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/codex --add-flags "-c features.daemon_auto_start=false"
    '';
    inherit (codex) version meta;
  }
