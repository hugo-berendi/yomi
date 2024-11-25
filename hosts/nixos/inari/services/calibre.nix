{config, ...}: {
  services = {
    calibre-server = {
      enable = true;
      port = config.yomi.ports.calibre-server;
      libraries = [
        "/var/lib/media/books"
      ];
    };
    calibre-web = {
    };
  };
}
