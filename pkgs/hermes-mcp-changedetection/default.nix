{
  lib,
  python312,
  stdenvNoCC,
  makeWrapper,
}: let
  pythonEnv = python312.withPackages (ps:
    with ps; [
      mcp
      requests
    ]);
in
  stdenvNoCC.mkDerivation {
    pname = "hermes-mcp-changedetection";
    version = "1.0.0";

    src = ./.;

    nativeBuildInputs = [makeWrapper];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin
      cp server.py $out/bin/.hermes-mcp-changedetection-unwrapped
      makeWrapper ${pythonEnv}/bin/python3 $out/bin/hermes-mcp-changedetection \
        --add-flags $out/bin/.hermes-mcp-changedetection-unwrapped

      runHook postInstall
    '';

    meta = {
      description = "MCP server for changedetection.io watch management";
      license = lib.licenses.mit;
      mainProgram = "hermes-mcp-changedetection";
    };
  }
