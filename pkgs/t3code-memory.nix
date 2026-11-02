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
      hash = "sha256-LxE/dyp9J1LNeC5U8eBFQY4MfVbnRR3a8HuGPJFmER4=";
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
    installPhase = ''
      mkdir -p "$out/bin"
      cp apps/server/dist-exe/t3 "$out/bin/t3"
    '';
    dontStrip = true;
  })
