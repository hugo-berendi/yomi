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
  version = "0.1.6";

  src = fetchFromGitHub {
    owner = "pingdotgg";
    repo = "t3code";
    rev = "2359643cffa6ba9ee84d6f2694b935de54a8013e";
    hash = "sha256-GWO+/gJWLu9GUwZCbmrBYIVn9Y7N8PwXrjQYFLOtmWk=";
  };

  patches = [./patches/t3code/shared-memory.patch];
  pnpmDeps = fetchPnpmDeps {
    inherit (final) pname version src patches;
    pnpm = pnpm_12;
    fetcherVersion = 4;
    hash = "sha256-uk2GkyazT9HWh/CGcwBS3wnRaKuU/7unZvabx8BA7Vg=";
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
