{
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpm_12,
  pnpmConfigHook,
}: let
  # The upstream SEA build requires its exact Node version (nodejs/node#67048).
  nodePkgs = import (builtins.fetchTree {
    type = "github";
    owner = "NixOS";
    repo = "nixpkgs";
    rev = "607036aace1dbcfeb0897d709519ca14f82ba227";
    narHash = "sha256-y6FSM8JvGew+KHVtHHZjD++9ZeuZzOltKSK7gFDFbFA=";
  }) {system = stdenv.hostPlatform.system;};
in
  stdenv.mkDerivation (final: {
    pname = "t3code-memory-server";
    version = "0.1.7";

    src = fetchFromGitHub {
      owner = "pingdotgg";
      repo = "t3code";
      rev = "322f6544dfad0a3c8a0c8cbecf2c7f7874b14268";
      hash = "sha256-oQLmDCDuJPNBsf8MHMD2xhMq+CF6L836/PQesM91Clw=";
    };

    patches = [
      ./patches/t3code/shared-memory.patch
      ./patches/t3code/pocket-id.patch
      ./patches/t3code/repair-cli.patch
    ];
    pnpmDeps = fetchPnpmDeps {
      inherit (final) pname version src patches;
      pnpm = pnpm_12;
      fetcherVersion = 4;
      hash = "sha256-1vScvol//sRdCwnEJTGmjo+pbMrUP+TshbWaN1mjO+I=";
    };

    # Upstream tags the commit before its release job commits the version bump, and
    # CI aligns the manifests on the runner instead. Built from the tag, the binary
    # would report the previous release (pingdotgg/t3code#28152). Not in pnpmDeps:
    # the lockfile does not depend on the version.
    postPatch = ''
      sed -i 's/^  "version": ".*",$/  "version": "${final.version}",/' apps/server/package.json
    '';

    nativeBuildInputs = [nodePkgs.nodejs-slim_26 pnpm_12 pnpmConfigHook];
    buildPhase = ''
      runHook preBuild
      export PATH="$PWD/node_modules/.bin:$PATH"
      node apps/server/scripts/cli.ts build-exe
      runHook postBuild
    '';
    doCheck = true;
    checkPhase = ''
      runHook preCheck
      (cd apps/server && pnpm exec vp test run src/auth/OidcLogin.test.ts src/http.test.ts src/auth/http.test.ts src/cli/thread.test.ts)
      apps/server/dist-exe/t3 thread start --help > thread-help.txt
      for flag in --reasoning-effort --runtime-mode; do
        if ! grep -q -- "$flag" thread-help.txt; then
          echo "Missing repair CLI flag: $flag" >&2
          exit 1
        fi
      done
      runHook postCheck
    '';
    installPhase = ''
      mkdir -p "$out/bin"
      cp apps/server/dist-exe/t3 "$out/bin/t3"
    '';
    dontStrip = true;
  })
