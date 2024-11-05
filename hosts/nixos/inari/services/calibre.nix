{config, ...}: {
  services.calibre-web = {
    enable = true;
    listen = {
      port = config.yomi.ports.calibre-web;
      ip = "0.0.0.0";
    };
  };
}
