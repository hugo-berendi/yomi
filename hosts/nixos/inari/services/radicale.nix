{config, ...}: let
  port = config.yomi.ports.radicale;
  dataDir = "/persist/data/radicale";
in {
  services.radicale = {
    enable = true;

    settings = {
      auth.type = "none"; # default is denyall
      server.hosts = ["localhost:${toString port}"];
      storage.filesystem_folder = dataDir;
    };
  };

  systemd.tmpfiles.rules = ["d ${dataDir} 0700 radicale radicale"];
  yomi.nginx.at.cal.port = port;
}
