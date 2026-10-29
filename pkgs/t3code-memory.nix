{
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpm_12,
  pnpmConfigHook,
  nodejs-slim_26,
}:
stdenv.mkDerivation (final: {
  pname = "t3code-memory-server";
  version = "0.1.2";

  src = fetchFromGitHub {
    owner = "pingdotgg";
    repo = "t3code";
    rev = "044f07257c9684ae4543bd1e1ebf9c394e9e3830";
    hash = "sha256-C5l7541kanlsukhswrAEu8GFpr/YpWDnofJ5dlg7+LM=";
  };

  patches = [./patches/t3code/shared-memory.patch];
  pnpmDeps = fetchPnpmDeps {
    inherit (final) pname version src patches;
    pnpm = pnpm_12;
    fetcherVersion = 4;
    hash = "sha256-Z0/53pCvwTJnXrX0lhUYji2/5z9OzuRcgR82T6Eri+A=";
  };

  nativeBuildInputs = [nodejs-slim_26 pnpm_12 pnpmConfigHook];
  buildPhase = ''
    runHook preBuild
    export PATH="$PWD/node_modules/.bin:$PATH"
    node apps/server/scripts/cli.ts build-exe
    runHook postBuild
  '';
  installPhase = ''
    mkdir -p "$out/bin"
    cp apps/server/dist-exe/t3 "$out/bin/t3"
  '';
  dontStrip = true;
})
