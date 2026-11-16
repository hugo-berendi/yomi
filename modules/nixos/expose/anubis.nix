{
  config,
  lib,
  ...
}: let
  cfg = config.yomi.expose;
  protected = lib.filterAttrs (_: e: e.enable && e.enableAnubis) cfg.at;
in {
  config = lib.mkIf cfg.enable {
    services.anubis.instances = lib.mapAttrs' (name: e:
      lib.nameValuePair "expose-${name}" {
        settings = {
          BIND_NETWORK = "tcp";
          BIND = "127.0.0.1:${toString e.anubis.port}";
          METRICS_BIND_NETWORK = "tcp";
          METRICS_BIND = "127.0.0.1:${toString e.anubis.metricsPort}";
          TARGET = "${e.protocol}://${e.proxyAddress}:${toString e.port}";
          # Newt is the socket peer. Traefik supplies the sanitized client IP;
          # using the socket address would bind every client's token to Newt.
          USE_REMOTE_ADDRESS = false;
        };
      })
    protected;

    yomi.ports = lib.mkMerge (lib.mapAttrsToList (name: e: {
        "expose-anubis-${name}" = e.anubis.port;
        "expose-anubis-metrics-${name}" = e.anubis.metricsPort;
      })
      protected);
  };
}
