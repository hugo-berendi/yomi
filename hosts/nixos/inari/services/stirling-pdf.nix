{
  config,
  lib,
  ...
}: {
  yomi.nginx.at.pdf.port = config.yomi.ports.stirling-pdf;

  services.stirling-pdf = {
    enable = true;
    environment = {
      SERVER_PORT = config.yomi.nginx.at.pdf.port;
    };
  };

  systemd.services.stirling-pdf.serviceConfig = lib.mkMerge [
    {
      PrivateTmp = true;
      ProtectSystem = "strict";
      PrivateMounts = true;
      RestrictSUIDSGID = true;
    }
  ];
}
