{config, ...}: {
  yomi.nginx.at.pdf.port = config.yomi.ports.stirling-pdf;

  services.stirling-pdf = {
    enable = true;
    environment = {
      SERVER_PORT = config.yomi.nginx.at.pdf.port;
    };
  };
}
