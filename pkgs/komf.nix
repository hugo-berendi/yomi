{
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  jre_headless,
  lib,
}:
stdenvNoCC.mkDerivation rec {
  pname = "komf";
  version = "1.7.1";

  src = fetchurl {
    url = "https://github.com/Snd-R/komf/releases/download/${version}/komf-${version}.jar";
    hash = "sha256-reVCSNj4FlKILXSRuRw/m7uv/SjTXS0Ch1snrNWJBNE=";
  };

  nativeBuildInputs = [makeWrapper];
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    install -Dm644 "$src" "$out/share/komf/komf.jar"
    makeWrapper ${jre_headless}/bin/java "$out/bin/komf" --add-flags "-jar $out/share/komf/komf.jar"
    runHook postInstall
  '';

  meta = {
    description = "Komga and Kavita metadata fetcher";
    homepage = "https://github.com/Snd-R/komf";
    license = lib.licenses.mit;
    mainProgram = "komf";
    platforms = lib.platforms.linux;
  };
}
