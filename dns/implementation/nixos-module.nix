{
  config,
  pkgs,
  lib,
  ...
}: let
  format = pkgs.formats.yaml {};
  cfg = config.yomi.dns;
in {
  options.yomi.dns = {
    domain = lib.mkOption {
      description = "Default zone to include records in";
      type = lib.types.str;
    };

    records = lib.mkOption {
      description = "List of records to create";
      default = [];
      type = lib.types.listOf (
        lib.types.submodule (
          {config, ...}: {
            options = {
              at = lib.mkOption {
                description = "Record name relative to its zone; empty or null denotes the apex.";
                type = lib.types.nullOr lib.types.str;
                apply = value:
                  if value == null
                  then ""
                  else value;
              };

              zone = lib.mkOption {
                description = "Zone this record is a part of";
                type = lib.types.str;
                default = cfg.domain;
              };

              type = lib.mkOption {
                type = lib.types.enum [
                  "A"
                  "AAAA"
                  "TXT"
                  "CNAME"
                  "MX"
                ];
                description = "The type of the DNS record";
              };

              to = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                description = "Shorthand for CNAME-ing to a subdomain of the given zone";
                default = null;
              };

              value = lib.mkOption {
                inherit (format) type;
                description = "The value assigned to the record, in octodns format";
              };

              ttl = lib.mkOption {
                type = lib.types.ints.between 1 2147483647;
                description = "The TTL assigned to the record";
                default = 300;
              };

              enableCloudflareProxy = lib.mkEnableOption "proxying using cloudflare";
            };

            config.value = lib.mkIf (
              config.type == "CNAME" && config.to != null
            ) "${config.to}.${config.zone}.";
          }
        )
      );
    };
  };
}
