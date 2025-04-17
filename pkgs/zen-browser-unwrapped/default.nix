{
  lib,
  stdenv,
  fetchurl,
  wrapGAppsHook3,
  autoPatchelfHook,
  alsa-lib,
  curl,
  dbus-glib,
  gtk3,
  libXtst,
  libva,
  pciutils,
  pipewire,
  adwaita-icon-theme,
  patchelfUnstable, # have to use patchelfUnstable to support --no-clobber-old-sections
}: let
  mozillaPlatforms = {
    "i686-linux" = "linux-i686";
    "x86_64-linux" = "linux-x86_64";
  };
in
  stdenv.mkDerivation rec {
    pname = "zen-browser-bin-unwrapped";
    version = "1.0.2-b.3";

    src = fetchurl {
      url = "https://github.com/zen-browser/desktop/releases/download/${version}/zen.linux-specific.tar.bz2";
      hash = "sha256-1kZTP05WuGIsxzcYYxIKJJd1OwhV5oacUbO56yADrL8=";
    };

    nativeBuildInputs = [
      wrapGAppsHook3
      autoPatchelfHook
      patchelfUnstable
    ];
    buildInputs = [
      gtk3
      adwaita-icon-theme
      alsa-lib
      dbus-glib
      libXtst
    ];
    runtimeDependencies = [
      curl
      libva.out
      pciutils
    ];
    appendRunpaths = [
      "${pipewire}/lib"
    ];
    # zen uses "relrhack" to manually process relocations from a fixed offset
    patchelfFlags = ["--no-clobber-old-sections"];

    installPhase = ''
      mkdir -p "$prefix/lib/${pname}"
      cp -r * "$prefix/lib/${pname}"

      mkdir -p "$out/bin"
      ln -s "$prefix/lib/${pname}/zen" "$out/bin/zen"

      install -D browser/chrome/icons/default/default16.png $out/share/icons/hicolor/16x16/apps/zen.png
      install -D browser/chrome/icons/default/default32.png $out/share/icons/hicolor/32x32/apps/zen.png
      install -D browser/chrome/icons/default/default48.png $out/share/icons/hicolor/48x48/apps/zen.png
      install -D browser/chrome/icons/default/default64.png $out/share/icons/hicolor/64x64/apps/zen.png
      install -D browser/chrome/icons/default/default128.png $out/share/icons/hicolor/128x128/apps/zen.png
    '';

    meta = {
      mainProgram = "zen";
      description = "Firefox based browser with a focus on privacy and customization (binary package)";
      homepage = "https://www.zen-browser.app/";
      license = lib.licenses.mpl20;
      maintainers = [];
      platforms = builtins.attrNames mozillaPlatforms;
    };

    passthru = {
      updateScript = ./update.sh;
      binaryName = meta.mainProgram;
      execdir = "/bin";
      libName = "${pname}";
      ffmpegSupport = true;
      gssSupport = true;
      gtk3 = gtk3;
    };
  }
