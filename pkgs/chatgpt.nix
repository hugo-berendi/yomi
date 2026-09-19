{
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  autoPatchelfHook,
  bubblewrap,
  cairo,
  cups,
  dbus,
  dconf,
  dpkg,
  expat,
  fetchurl,
  flock,
  gdk-pixbuf,
  glib,
  gtk3,
  lib,
  libgbm,
  libGL,
  libnotify,
  libpulseaudio,
  libsecret,
  libusb1,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  makeWrapper,
  nodejs-slim,
  nspr,
  nss,
  pango,
  pipewire,
  qt6,
  ripgrep,
  stdenv,
  systemdLibs,
  tectonic-unwrapped,
  vulkan-loader,
  wrapGAppsHook3,
  writeShellApplication,
  xdg-utils,
}: let
  version = "26.915.31945";
  launcher = import ./chatgpt-launcher.nix {
    inherit flock writeShellApplication;
  };
in
  stdenv.mkDerivation {
    pname = "chatgpt";
    inherit version;

    src = fetchurl {
      url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_${version}_amd64.deb";
      hash = "sha256-0nqcApGc/khNzF80WEueqf0NemXGncyHK1vc+g77WYM=";
    };

    strictDeps = true;

    nativeBuildInputs = [
      autoPatchelfHook
      dpkg
      makeWrapper
      qt6.wrapQtAppsHook
      wrapGAppsHook3
    ];

    buildInputs = [
      alsa-lib
      at-spi2-atk
      at-spi2-core
      atk
      cairo
      cups
      dbus
      dconf
      expat
      gdk-pixbuf
      glib
      gtk3
      libgbm
      libnotify
      libusb1
      libx11
      libxcb
      libxcomposite
      libxdamage
      libxext
      libxfixes
      libxkbcommon
      libxrandr
      nspr
      nss
      pango
      qt6.qtbase
      stdenv.cc.cc.lib
      systemdLibs
    ];

    runtimeDependencies = [
      libGL
      libnotify
      libpulseaudio
      libsecret
      pipewire
      vulkan-loader
    ];

    dontWrapGApps = true;
    dontWrapQtApps = true;
    dontStrip = true;

    unpackPhase = ''
      runHook preUnpack
      dpkg-deb -x "$src" .
      runHook postUnpack
    '';

    postPatch = ''
      grep -aFq 'const family = familySync();' usr/lib/chatgpt/resources/app.asar
      sed -i "s|const family = familySync();|const family = 'glibc'     ;|" usr/lib/chatgpt/resources/app.asar
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -r usr/* "$out"
      rm -f "$out/lib/chatgpt/libqt5_shim.so"

      resources="$out/lib/chatgpt/resources"
      find "$resources" -type d -name prebuilds -print0 | while IFS= read -r -d "" prebuildsPath; do
        find "$prebuildsPath" -mindepth 1 -maxdepth 1 \
          ! -name "*linux-x64" \
          -exec rm -rf -- {} +
      done
      find "$resources" -type f -name '*.musl.node' -delete

      ln -sf ${lib.getExe tectonic-unwrapped} "$resources/plugins/openai-bundled/plugins/latex/bin/tectonic"
      ln -sf ${lib.getExe ripgrep} "$resources/rg"
      ln -sf ${lib.getExe nodejs-slim} "$resources/cua_node/bin/node"
      install -Dm755 ${lib.getExe launcher} "$out/bin/chatgpt"
      runHook postInstall
    '';

    postFixup = ''
      wrapProgram "$out/bin/chatgpt" \
        "''${gappsWrapperArgs[@]}" \
        "''${qtWrapperArgs[@]}" \
        --set CHATGPT_EXECUTABLE "$out/lib/chatgpt/ChatGPT" \
        --set CHATGPT_RESOURCES_SOURCE "$out/lib/chatgpt/resources" \
        --set CHATGPT_RESOURCES_CACHE_LABEL ${lib.escapeShellArg "${version}-x86_64-linux"} \
        --prefix PATH : ${lib.makeBinPath [nodejs-slim xdg-utils bubblewrap]} \
        --set-default CODEX_BROWSER_USE_NODE_PATH ${lib.getExe nodejs-slim} \
        --set-default NODE_REPL_NODE_PATH ${lib.getExe nodejs-slim}
    '';

    meta = {
      description = "Desktop application for ChatGPT, Work, and Codex";
      homepage = "https://developers.openai.com/codex/app";
      license = lib.licenses.unfree;
      mainProgram = "chatgpt";
      platforms = ["x86_64-linux"];
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  }
