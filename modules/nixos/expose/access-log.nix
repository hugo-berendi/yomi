{
  config,
  lib,
  ...
}: let
  cfg = config.yomi.expose.server;
  logfile = "${config.services.pangolin.dataDir}/config/traefik/access.json";
in {
  options.yomi.expose.server.accessLog.enable = lib.mkEnableOption "local bounded HTTP access logs for security and geographic analysis" // {default = true;};
  config = lib.mkIf (cfg.enable && cfg.accessLog.enable) {
    services.traefik.staticConfigOptions.accessLog = {
      filePath = logfile;
      format = "json";
      fields = {
        # Keep source IPs for GeoIP analysis, never cookies, tokens, query
        # strings or request bodies. Pangolin analytics has its own settings.
        defaultMode = "drop";
        headers.defaultMode = "drop";
        names = lib.genAttrs ["StartUTC" "ClientHost" "RequestHost" "RequestMethod" "DownstreamStatus" "Duration" "RouterName"] (_: "keep");
      };
    };
    services.logrotate.settings.expose-access = {
      files = [logfile];
      frequency = "daily";
      maxsize = "10M";
      rotate = 7;
      compress = true;
      missingok = true;
      notifempty = true;
      copytruncate = true;
      su = "traefik fossorial";
    };
  };
}
