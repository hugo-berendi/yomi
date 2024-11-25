{
  config,
  lib,
  upkgs,
  ...
}: let
  port = config.yomi.ports.redlib;
in {
  services.redlib = {
    enable = true;
    port = port;
  };
  yomi.nginx.at.redlib.port = port;
}
