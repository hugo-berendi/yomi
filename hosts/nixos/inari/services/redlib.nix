{
  config,
  lib,
  upkgs,
  ...
}: let
  port = config.yomi.ports.redlib;
in {
  services.libreddit.enable = true;
  yomi.nginx.at.redlib.port = port;
  systemd.services.libreddit.serviceConfig.ExecStart =
    lib.mkForce "${upkgs.redlib}/bin/redlib --port ${toString port}";
}
