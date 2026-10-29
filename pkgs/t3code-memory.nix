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
  version = "0.1.3";

  src = fetchFromGitHub {
    owner = "pingdotgg";
    repo = "t3code";
    rev = "d2c440312e5f39d59827ed466838a623516454d6";
    hash = "sha256-xxmwaHPkXzR0CAtknCc6raAzcnPtmw8wxF3YO3WcbE4=";
  };

  patches = [./patches/t3code/shared-memory.patch];
  pnpmDeps = fetchPnpmDeps {
    inherit (final) pname version src patches;
    pnpm = pnpm_12;
    fetcherVersion = 4;
    hash = "sha256-VPK/r9/w51gE5RyEacRb4MRszGMuyhLARQd3a+wt+KE=";
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
