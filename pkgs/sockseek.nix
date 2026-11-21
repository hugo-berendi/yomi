{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  icu,
  openssl,
  zlib,
}:
# The upstream release is a self-contained single-file .NET build. Building
# from source would need a nuget lock file kept in step with every release;
# the binary only needs its native dependencies patched in.
stdenv.mkDerivation rec {
  pname = "sockseek";
  version = "3.1.0";

  src = fetchurl {
    url = "https://github.com/fiso64/sockseek/releases/download/v${version}/sockseek_${version}_linux-x64.tar.gz";
    hash = "sha256-GkTYt9PDNJetfhz3HIRcFigOIrF+1UncM2WO3mas4mQ=";
  };

  sourceRoot = ".";

  nativeBuildInputs = [autoPatchelfHook makeWrapper];
  buildInputs = [(lib.getLib stdenv.cc.cc) zlib];

  # A single-file bundle carries its managed payload appended to the ELF;
  # stripping would cut it off.
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 sockseek $out/libexec/sockseek
    # .NET loads ICU and OpenSSL with dlopen, which autoPatchelf cannot see.
    makeWrapper $out/libexec/sockseek $out/bin/sockseek \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [icu openssl]}
    runHook postInstall
  '';

  meta = {
    description = "Batch downloader for Soulseek with Spotify, YouTube and CSV playlist input";
    homepage = "https://github.com/fiso64/sockseek";
    license = lib.licenses.agpl3Only;
    mainProgram = "sockseek";
    platforms = ["x86_64-linux"];
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
}
