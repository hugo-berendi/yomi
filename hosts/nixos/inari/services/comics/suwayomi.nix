{config, ...}: let
  comicDir = "/raid5pool/media/comics";
in {
  yomi.nginx.at.suwayomi.port = 4567;

  services.suwayomi-server = {
    enable = true;
    dataDir = comicDir;
    settings = {
      server = {
        downloadAsCbz = true;
        downloadsPath = comicDir;
        autoDownloadNewChapters = true;

        port = config.yomi.nginx.at.suwayomi.port;

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
