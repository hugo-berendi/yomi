{
  config,
  lib,
  ...
}: let
  port = config.yomi.ports.redlib;
in {
  services.redlib = {
    enable = false;
    inherit port;
  };

  yomi.nginx.at.redlib = lib.mkIf config.services.redlib.enable {
    inherit port;
  };

  systemd.services.redlib.serviceConfig = lib.mkIf config.services.redlib.enable (lib.mkMerge [
    (lib.mapAttrs (_: lib.mkForce) config.yomi.hardening.presets.standard)
  ]);
}
