{config, ...}: let
  comicDir = "/raid5pool/media/comics";
in {
  yomi.cloudflared.at.suwayomi.port = 4567;

  sops.secrets.suwayomi = {
    sopsFile = ../secrets.yaml;
    owner = config.services.suwayomi-server.user;
    group = config.services.suwayomi-server.group;
  };

  services.suwayomi-server = {
    enable = true;
    user = "root";
    dataDir = comicDir;
    settings = {
      server = {
        port = config.yomi.cloudflared.at.suwayomi.port;
        extensionRepos = [
          "https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.min.json"
          "https://raw.githubusercontent.com/suwayomi/tachiyomi-extension/repo/index.min.json"
        ];
      };
    };
  };

  # {{{ Storage
  # environment.persistence."/persist/state".directories = [
  #   {
  #     inherit (config.services.suwayomi-server) user group;
  #     directory = config.services.suwayomi-server.dataDir;
  #     mode = "u=rwx,g=r,o=r";
  #   }
  # ];

  systemd.tmpfiles.rules = let
    dataDir = config.services.suwayomi-server.dataDir;
    user = {
      name = config.services.suwayomi-server.user;
      group = config.services.suwayomi-server.group;
    };
  in [
    "d ${dataDir}                 0755 ${user.name} ${user.group}"
    "d ${dataDir}/.local/share/Tachidesk                 0755 ${user.name} ${user.group}"
  ];
  # }}}
}
