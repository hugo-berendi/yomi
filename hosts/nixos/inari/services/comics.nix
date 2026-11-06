{
  config,
  lib,
  pkgs,
  ...
}: let
  comicDir = "/raid5pool/media/comics";
  port = config.yomi.nginx.at.suwayomi.port;
in {
  yomi.nginx.at.suwayomi.port = config.yomi.ports.suwayomi;

  services.suwayomi-server = {
    enable = true;
    package = pkgs.suwayomi-server;
    dataDir = comicDir;
    settings = {
      server = {
        ip = "127.0.0.1";
        inherit port;

        systemTrayEnabled = false;
        initialOpenInBrowserEnabled = false;

        webUIEnabled = true;
        webUIFlavor = "WebUI";
        webUIChannel = "STABLE";
        webUIInterface = "browser";

        downloadAsCbz = true;
        downloadsPath = comicDir;
        autoDownloadNewChapters = true;
        excludeEntryWithUnreadChapters = true;

        extensionRepos = [
          "https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.min.json"
          "https://raw.githubusercontent.com/suwayomi/tachiyomi-extension/repo/index.min.json"
        ];

        flareSolverrEnabled = true;
        flareSolverrUrl = "http://localhost:${toString config.yomi.ports.flaresolverr}";
      };
    };
  };

  # {{{ WebView
  # Suwayomi downloads a prebuilt Chromium (KCEF) into bin/kcef on first use. Its
  # libjcef.so links against system libraries NixOS has no global copy of, so the
  # WebView died with an UnsatisfiedLinkError (libcups, libcairo, libpango, libXtst
  # reported missing by `ldd`). The WebView is how a site login, such as Asura
  # premium, reaches the extensions' cookie jar. cef_server itself runs via nix-ld.
  systemd.services.suwayomi-server.environment.LD_LIBRARY_PATH = lib.makeLibraryPath (with pkgs; [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    glib
    libdrm
    libgbm
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxi
    libxkbcommon
    libxrandr
    libxrender
    libxtst
    nspr
    nss
    pango
    stdenv.cc.cc.lib
    systemd
  ]);
  # }}}

  # {{{ Storage
  systemd.tmpfiles.rules = let
    dataDir = config.services.suwayomi-server.dataDir;
    user = {
      name = config.services.suwayomi-server.user;
      group = config.services.suwayomi-server.group;
    };
  in [
    "d ${dataDir}                         0755 ${user.name} ${user.group}"
    "d ${dataDir}/.local/share/Tachidesk  0755 ${user.name} ${user.group}"
  ];
  # }}}
}
