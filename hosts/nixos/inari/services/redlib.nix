{
  config,
  lib,
  ...
}: let
  port = config.yomi.ports.redlib;
in {
  services.redlib = {
    enable = true;
    port = port;
  };
  yomi.nginx.at.redlib.port = port;

  systemd.services.redlib.serviceConfig = lib.mkMerge [
    (lib.mapAttrs (_: lib.mkForce) config.yomi.hardening.presets.standard)
  ];
}
