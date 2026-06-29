{
  lib,
  python312,
  stdenvNoCC,
  makeWrapper,
}: let
  pythonEnv = python312.withPackages (ps:
    with ps; [
      mcp
      caldav
    ]);
in
  stdenvNoCC.mkDerivation {
    pname = "hermes-mcp-radicale";
    version = "1.0.0";

    src = ./.;

    nativeBuildInputs = [makeWrapper];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin
      cp server.py $out/bin/.hermes-mcp-radicale-unwrapped
      makeWrapper ${pythonEnv}/bin/python3 $out/bin/hermes-mcp-radicale \
        --add-flags $out/bin/.hermes-mcp-radicale-unwrapped

      runHook postInstall
    '';

    meta = {
      description = "MCP server for Radicale CalDAV calendar access";
      license = lib.licenses.mit;
      mainProgram = "hermes-mcp-radicale";
    };
  }
