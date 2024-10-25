{
  config,
  lib,
  upkgs,
  ...
}: let
  port = config.yomi.ports.redlib;
in {
  services.redlib.enable = true;
  yomi.nginx.at.redlib.port = port;
  systemd.services.redlib.serviceConfig.ExecStart =
    lib.mkForce "${upkgs.redlib}/bin/redlib --port ${toString port}";
}
