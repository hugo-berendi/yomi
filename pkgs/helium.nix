{
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  autoPatchelfHook,
  cairo,
  copyDesktopItems,
  cups,
  dbus,
  expat,
  fetchurl,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gtk3,
  lib,
  libdrm,
  libgbm,
  libGL,
  libpulseaudio,
  libuuid,
  libx11,
  libxcb,
  libxcomposite,
  libxcursor,
  libxdamage,
  libxext,
  libxfixes,
  libxi,
  libxkbcommon,
  libxrandr,
  libxrender,
  libxshmfence,
  libxscrnsaver,
  libxtst,
  makeDesktopItem,
  makeWrapper,
  mesa,
  nspr,
  nss,
  pango,
  pipewire,
  qt6,
  stdenv,
  systemd,
  vulkan-loader,
  wayland,
}: let
  version = "0.16.3.1";
in
  stdenv.mkDerivation {
    pname = "helium";
    inherit version;

    src = fetchurl {
      url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-${version}-x86_64_linux.tar.xz";
      hash = "sha256-Y07fuk0C6rUEjz6PHGRMJDfBL7TM2xlggXKtG4lWy+s=";
    };

    nativeBuildInputs = [
      autoPatchelfHook
      copyDesktopItems
      makeWrapper
    ];

    buildInputs = [
      alsa-lib
      at-spi2-atk
      at-spi2-core
      atk
      cairo
      cups
      dbus
      expat
      fontconfig
      freetype
      gdk-pixbuf
      glib
      gtk3
      libdrm
      libgbm
      libGL
      libpulseaudio
      libuuid
      libx11
      libxcb
      libxcomposite
      libxcursor
      libxdamage
      libxext
      libxfixes
      libxi
      libxkbcommon
      libxrandr
      libxrender
      libxshmfence
      libxscrnsaver
      libxtst
      mesa
      nspr
      nss
      pango
      pipewire
      qt6.qtbase
      systemd
      vulkan-loader
      wayland
    ];

    autoPatchelfIgnoreMissingDeps = [
      "libQt5Core.so.5"
      "libQt5Gui.so.5"
      "libQt5Widgets.so.5"
    ];

    dontWrapQtApps = true;

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/bin" "$out/opt/helium" "$out/share/icons/hicolor/256x256/apps"
      cp -r ./* "$out/opt/helium"
      cp product_logo_256.png "$out/share/icons/hicolor/256x256/apps/helium.png"
      makeWrapper "$out/opt/helium/helium" "$out/bin/helium" \
        --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [libGL mesa pipewire alsa-lib libpulseaudio]} \
        --add-flags "--ozone-platform-hint=auto" \
        --add-flags "--gtk-version=3" \
        --add-flags "--enable-features=WaylandWindowDecorations" \
        --add-flags "--disable-component-update" \
        --add-flags "--check-for-update-interval=0"
      runHook postInstall
    '';

    desktopItems = [
      (makeDesktopItem {
        name = "helium";
        exec = "helium %U";
        icon = "helium";
        desktopName = "Helium";
        genericName = "Web Browser";
        categories = ["Network" "WebBrowser"];
        mimeTypes = [
          "application/xhtml+xml"
          "text/html"
          "text/xml"
          "x-scheme-handler/http"
          "x-scheme-handler/https"
        ];
      })
    ];

    meta = {
      description = "Private, fast, and honest Chromium-based web browser";
      homepage = "https://helium.computer";
      license = lib.licenses.gpl3Only;
      mainProgram = "helium";
      platforms = ["x86_64-linux"];
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  }
