{
  lib,
  domain,
}: {
  name,
  config,
  ...
}: {
  options = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to publish this endpoint and its DNS and monitoring records.";
    };
    subdomain = lib.mkOption {
      type = lib.types.str;
      default = name;
      description = "Default DNS name within the provider's domain; empty means the zone apex.";
    };
    host = lib.mkOption {
      type = lib.types.str;
      default =
        if config.subdomain == ""
        then domain
        else "${config.subdomain}.${domain}";
      description = "Hostname served by this endpoint.";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "https://${config.host}";
      readOnly = true;
      description = "Derived public HTTPS URL.";
    };
    protocol = lib.mkOption {
      type = lib.types.enum ["http" "https"];
      default = "http";
      description = "Protocol spoken by the upstream HTTP application.";
    };
    proxyAddress = lib.mkOption {
      type = lib.types.str;
      default = "localhost";
      description = "Upstream address, with brackets around an IPv6 literal.";
    };
    dns = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Manage a DNS record; disable for externally managed hostnames.";
      };
      zone = lib.mkOption {
        type = lib.types.str;
        default = domain;
        description = "Managed DNS zone.";
      };
      name = lib.mkOption {
        type = lib.types.str;
        default = config.subdomain;
        description = "Record name relative to dns.zone; empty means the apex.";
      };
    };
    monitor = {
      enable = lib.mkEnableOption "a Gatus health check for this endpoint";
      name = lib.mkOption {
        type = lib.types.str;
        default = name;
        description = "Health check display name.";
      };
      group = lib.mkOption {
        type = lib.types.str;
        default = "Services";
        description = "Health check group.";
      };
      path = lib.mkOption {
        type = lib.types.strMatching "(/.*)?";
        default = "";
        description = "Health check path appended to the public URL.";
      };
      interval = lib.mkOption {
        type = lib.types.str;
        default = "1m";
        description = "Gatus check interval.";
      };
      conditions = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["[STATUS] == 200" "[RESPONSE_TIME] < 2000"];
        description = "Expected Gatus responses; configure authentication and redirects explicitly.";
      };
    };
  };
}
