{config, ...}: let
  port = config.yomi.ports.radicale;
  dataDir = "/persist/data/radicale";
in {
  services.radicale = {
    enable = true;

    settings = {
      auth = {
        type = "htpasswd";
        htpasswd_filename = config.sops.secrets.radicale_htpasswd.path;
        htpasswd_encryption = "autodetect";
      };
      server.hosts = ["localhost:${toString port}"];
      storage.filesystem_folder = dataDir;
    };
  };

  systemd.tmpfiles.rules = ["d ${dataDir} 0700 radicale radicale"];
  yomi.nginx.at.cal.port = port;
  sops.secrets.radicale_htpasswd = {
    sopsFile = ../secrets.yaml;
    owner = config.systemd.services.radicale.serviceConfig.User;
    group = config.systemd.services.radicale.serviceConfig.Group;
  };
}
