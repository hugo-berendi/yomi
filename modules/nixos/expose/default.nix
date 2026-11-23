{
  config,
  lib,
  pkgs,
  upkgs,
  ...
}: let
  cfg = config.yomi.expose;
  format = pkgs.formats.yaml {};
  enabled = lib.filterAttrs (_: e: e.enable);
  web = enabled cfg.at;
  private = enabled cfg.private;
  raw = protocol:
    lib.mapAttrsToList (name: e: {
      inherit name protocol;
      inherit (e) port publicPort proxyAddress;
    }) (enabled cfg.${protocol});
  rawEntries = raw "tcp" ++ raw "udp";
  prefix = name: "${config.networking.hostName}-${name}";
  inherit (import ./private-resources.nix {inherit lib;}) allowed privateResource privateAssertions;
  backend = e: target:
    target
    // lib.optionalAttrs e.healthCheck.enable {
      healthcheck = {
        inherit (target) hostname port;
        inherit (e.healthCheck) path interval timeout status;
        scheme = target.method;
        enabled = true;
      };
    };
  blueprint = {
    # Prefix IDs to avoid resource takeover when different sites reuse a name.
    "public-resources" =
      lib.mapAttrs' (name: e:
        lib.nameValuePair (prefix "web-${name}") ({
            inherit name;
            mode = "http";
            full-domain = e.host;
            inherit (e) labels;
            rules = lib.imap0 (i: rule: rule // {priority = i;}) (
              map (value: {
                action = "deny";
                match = "country";
                inherit value;
              })
              e.blockedCountries
              ++ map (asn: {
                action = "deny";
                match = "asn";
                value = "AS${toString asn}";
              })
              e.blockedASNs
              ++ e.rules
              ++ map (value: {
                action = "pass";
                match = "country";
                inherit value;
              })
              e.allowedCountries
              # COUNTRY=ALL skips private/CGNAT IPs upstream. CIDR catch-alls
              # also reject unknown or misclassified locations.
              ++ lib.optionals (e.allowedCountries != []) [
                {
                  action = "deny";
                  match = "cidr";
                  value = "0.0.0.0/0";
                }
                {
                  action = "deny";
                  match = "cidr";
                  value = "::/0";
                }
              ]
            );
            auth = {
              sso-enabled = e.sso;
              sso-roles = e.roles;
              sso-users = e.users;
            };
            targets =
              [
                ({
                    hostname =
                      if e.enableAnubis
                      then "127.0.0.1"
                      else e.proxyAddress;
                    port =
                      if e.enableAnubis
                      then e.anubis.port
                      else e.port;
                    method =
                      if e.enableAnubis
                      then "http"
                      else e.protocol;
                  }
                  // lib.optionalAttrs e.healthCheck.enable {
                    inherit
                      (backend e {
                        hostname = e.proxyAddress;
                        inherit (e) port;
                        method = e.protocol;
                      })
                      healthcheck
                      ;
                  })
              ]
              ++ map (backend e) e.additionalTargets;
          }
          // lib.optionalAttrs (e.hostHeader != null) {"host-header" = e.hostHeader;}))
      web
      // builtins.listToAttrs (map (e:
        lib.nameValuePair (prefix "${e.protocol}-${e.name}") {
          inherit (e) name;
          mode = e.protocol;
          proxy-port = e.publicPort;
          targets = [
            {
              hostname = e.proxyAddress;
              inherit (e) port;
            }
          ];
        })
      rawEntries);
    "private-resources" = lib.mapAttrs' (name: e:
      lib.nameValuePair (prefix "private-${name}") (privateResource name e))
    private;
  };
in {
  imports = [./endpoints.nix ./server.nix ./anubis.nix];

  options.yomi.expose = {
    allowedCountries = lib.mkOption {
      type = lib.types.listOf (lib.types.strMatching "[A-Z]{2}");
      default = [];
      description = "Default country allowlist for public HTTP resources. Empty means unrestricted geography. Passing countries still authenticate.";
    };
    enable = lib.mkEnableOption "the Pangolin site connector (Newt)";
    domain = lib.mkOption {
      type = lib.types.str;
      default = config.yomi.dns.domain;
      description = "Default domain for public Web resources.";
    };
    publicHost = lib.mkOption {
      type = lib.types.str;
      default = "ebisu.${cfg.domain}";
      description = "Unproxied DNS hostname of the public Pangolin gateway.";
    };
    endpoint = lib.mkOption {
      type = lib.types.str;
      default = "https://pangolin.${cfg.domain}";
      description = "Pangolin control server URL.";
    };
    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Runtime file with NEWT_ID and NEWT_SECRET; never put credentials in Nix expressions.";
    };
    blueprint = lib.mkOption {
      inherit (format) type;
      readOnly = true;
      default = blueprint;
      description = "Generated site blueprint, also available before activating the connector.";
    };
    listeners = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      readOnly = true;
      default =
        map (e: {
          inherit (e) protocol;
          port = e.publicPort;
        })
        rawEntries;
      description = "Public gateway listeners required by this site's raw resources.";
    };
  };

  config = lib.mkMerge [
    {
      # Stable's Newt 1.12 cannot implement the exit-node resources supported
      # by Pangolin 1.24. Keep the NixOS service and use the pinned newer client.
      services.newt.package = lib.mkDefault upkgs.fosrl-newt;
      system.build.exposeBlueprint = format.generate "${config.networking.hostName}-pangolin.yaml" cfg.blueprint;
      assertions =
        (map (e: {
          assertion = !e.sso || allowed e;
          message = "Pangolin ${e.host}: SSO requires explicit users or roles.";
        }) (lib.attrValues web))
        ++ (map (e: {
          assertion = (!e.enableAnubis || e.additionalTargets == []) && (e.allowAuthBypass || !lib.any (r: r.action == "allow") e.rules) && (e.allowedCountries == [] || lib.all (r: r.action == "deny") e.rules);
          message = "Expose ${e.host}: Anubis needs one backend; allow requires allowAuthBypass; country allowlists may only be combined with custom deny rules to prevent geography bypass.";
        }) (lib.attrValues web))
        ++ lib.concatLists (lib.mapAttrsToList privateAssertions private)
        ++ [
          {
            assertion = lib.all (e: !lib.elem "Admin" e.roles) (lib.attrValues web);
            message = "Pangolin's Admin role is implicit and must not be listed in SSO roles.";
          }
          {
            assertion = !lib.any (e: e.mode == "exit-node") (lib.attrValues private) || lib.versionAtLeast config.services.newt.package.version "1.18.0";
            message = "Pangolin exit nodes require Newt 1.18.0 or newer.";
          }
        ];
    }
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.environmentFile != null && lib.hasPrefix "/" cfg.environmentFile && !lib.hasPrefix "/nix/store/" cfg.environmentFile;
          message = "Pangolin connector requires a runtime environmentFile with site credentials.";
        }
      ];
      services.newt = {
        enable = true;
        inherit (cfg) environmentFile blueprint;
        settings.endpoint = cfg.endpoint;
      };
      yomi.dns.records = lib.mapAttrsToList (_: e: {
        type =
          if e.dns.name == ""
          then "ALIAS"
          else "CNAME";
        at = e.dns.name;
        zone = e.dns.zone;
        value = "${cfg.publicHost}.";
        enableCloudflareProxy = false;
      }) (lib.filterAttrs (_: e: e.dns.enable) web);
    })
  ];
}
