{
  config,
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
