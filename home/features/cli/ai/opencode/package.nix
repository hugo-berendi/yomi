# Keep T3's 2.0 protocol while backporting Copilot Free/Student Auto routing.
# PR https://github.com/anomalyco/opencode/pull/55960, head 491587b.
{pkgs, ...}: let
  source = pkgs.fetchzip {
    url = "https://codeload.github.com/anomalyco/opencode/tar.gz/refs/tags/v2.0.32";
    hash = "sha256-KATNzF7z3PoUo30KC13Gm8uC6HA2a9bmJCZRfqY5D44=";
  };
  runtime = pkgs.stdenvNoCC.mkDerivation {
    pname = "opencode-copilot-auto-runtime";
    version = "2.0.32";
    src = source;
    patches = [./copilot-auto.patch];
    nativeBuildInputs = [pkgs.bun pkgs.cacert pkgs.git];
    dontConfigure = true;
    # Fetch only public, lockfile-pinned dependencies. Lifecycle scripts are disabled.
    buildPhase = ''
      runHook preBuild
      export HOME="$TMPDIR/home"
      mkdir -p "$HOME"
      bun install --frozen-lockfile --ignore-scripts --filter @opencode/cli
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -a . "$out/source"
      runHook postInstall
    '';
    dontFixup = true;
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-5nv38Bp1ihTJbVIaUqgOci47lBjNGttknakYDFNdNjk=";
  };
  versionPreload = pkgs.writeText "opencode-release-preload.js" ''
    globalThis.OPENCODE_VERSION = "2.0.32";
    globalThis.OPENCODE_CHANNEL = "latest";
    globalThis.OPENCODE_ARTIFACT = "cli";
  '';
in
  pkgs.writeShellApplication {
    name = "opencode";
    runtimeInputs = [pkgs.bun];
    text = ''
      if [ -r "$HOME/.t3/opencode-server.env" ]; then
        set -a
        # shellcheck disable=SC1091
        . "$HOME/.t3/opencode-server.env"
        set +a
      fi
      export BUN_OPTIONS="--conditions=browser --preload=${versionPreload} --preload=${runtime}/source/packages/tui/node_modules/@opentui/solid/scripts/preload.js"
      exec bun run ${runtime}/source/packages/cli/src/index.ts "$@"
    '';
    passthru = {inherit runtime;};
    meta = {
      description = "OpenCode 2.0.32 with Copilot Auto routing for Free and Student";
      homepage = "https://github.com/anomalyco/opencode";
      license = pkgs.lib.licenses.mit;
      platforms = ["x86_64-linux"];
      mainProgram = "opencode";
    };
  }
