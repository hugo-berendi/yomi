{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  jdk21_headless,
}: let
  jdk = jdk21_headless;
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "suwayomi-server";
    version = "2.3.2243";

    src = fetchurl {
      url = "https://github.com/Suwayomi/Suwayomi-Server/releases/download/v${finalAttrs.version}/Suwayomi-Server-v${finalAttrs.version}.jar";
      hash = "sha256-wDecRxon4qk1UeZfm7/3eU0EkDiGGKQzNKnHiTvlksE=";
    };

    nativeBuildInputs = [makeWrapper];
    dontUnpack = true;

    buildPhase = ''
      runHook preBuild

      makeWrapper ${jdk}/bin/java $out/bin/tachidesk-server \
        --add-flags "-Dsuwayomi.tachidesk.config.server.initialOpenInBrowserEnabled=false -jar $src"

      runHook postBuild
    '';

    meta = {
      description = "Free and open source manga reader server that runs extensions built for Mihon (Tachiyomi)";
      homepage = "https://github.com/Suwayomi/Suwayomi-Server";
      downloadPage = "https://github.com/Suwayomi/Suwayomi-Server/releases";
      changelog = "https://github.com/Suwayomi/Suwayomi-Server/releases/tag/v${finalAttrs.version}";
      license = lib.licenses.mpl20;
      platforms = jdk.meta.platforms;
      sourceProvenance = [lib.sourceTypes.binaryBytecode];
      mainProgram = "tachidesk-server";
    };
  })
