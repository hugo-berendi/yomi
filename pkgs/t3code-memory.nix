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
  version = "0.1.5";

  src = fetchFromGitHub {
    owner = "pingdotgg";
    repo = "t3code";
    rev = "6d450a4284852af137b2f3407fddd89eb76e7644";
    hash = "sha256-MUIf+6/gk2jG3eziHFjtvOfooDeQbbcJxMBECFZh6KQ=";
  };

  patches = [./patches/t3code/shared-memory.patch];
  pnpmDeps = fetchPnpmDeps {
    inherit (final) pname version src patches;
    pnpm = pnpm_12;
    fetcherVersion = 4;
    hash = "sha256-euPXYkQ4447Y08TI00HpZhRMYjr39mMTcok+JvMwIW4=";
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
