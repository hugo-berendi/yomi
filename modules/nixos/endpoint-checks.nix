{
  config,
  lib,
  ...
}: let
  nginx = lib.filterAttrs (_: e: e.enable && config.yomi.nginx.enable) config.yomi.nginx.at;
  tunnel = lib.filterAttrs (_: e: e.enable) config.yomi.cloudflared.at;
  entries = lib.attrValues nginx ++ lib.attrValues tunnel;
in {
  config.assertions =
    (map (e: {
        assertion =
          !e.dns.enable
          || e.host
          == (
            if e.dns.name == ""
            then e.dns.zone
            else "${e.dns.name}.${e.dns.zone}"
          );
        message = "Endpoint ${e.host}: dns.name and dns.zone must match host, or dns.enable must be false.";
      })
      entries)
    ++ (map (entries: {
      assertion = let hosts = map (e: e.host) (lib.attrValues entries); in builtins.length hosts == builtins.length (lib.unique hosts);
      message = "Endpoint hostnames must be unique within each proxy provider.";
    }) [nginx tunnel]);
}
