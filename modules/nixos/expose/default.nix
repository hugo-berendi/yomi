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
  allowed = e: e.users != [] || e.roles != [];
  portString = ports: lib.concatMapStringsSep "," toString ports;
  hasPortRestrictions = e: lib.elem e.mode ["host" "cidr" "ssh"];
  usesDomain = e: lib.elem e.mode ["http" "inference"];
  destinationPort = e:
    if e.destinationPort == null && e.mode == "ssh"
    then 22
    else e.destinationPort;
  tcpPorts = e:
    if e.mode == "ssh" && e.tcpPorts == []
    then [(destinationPort e)]
    else e.tcpPorts;
  privateResource = name: e:
    {
      inherit name;
      inherit (e) mode users roles;
    }
    // lib.optionalAttrs (e.labels != []) {inherit (e) labels;}
    // lib.optionalAttrs (e.machines != []) {inherit (e) machines;}
    // lib.optionalAttrs (e.sites != []) {inherit (e) sites;}
    // lib.optionalAttrs (e.destination != null) {inherit (e) destination;}
    // lib.optionalAttrs (e.destination != null && destinationPort e != null) {
      destination-port = destinationPort e;
    }
    // lib.optionalAttrs (hasPortRestrictions e) {
      tcp-ports = portString (tcpPorts e);
      udp-ports = portString e.udpPorts;
      disable-icmp = !e.allowICMP;
    }
    // lib.optionalAttrs (e.alias != null) {inherit (e) alias;}
    // lib.optionalAttrs (usesDomain e) {
      full-domain = e.fullDomain;
      ssl = e.ssl != false;
    }
    // lib.optionalAttrs (e.mode == "http") {
      scheme =
        if e.scheme == null
        then "http"
        else e.scheme;
    }
    // lib.optionalAttrs (e.mode == "ssh") {
      auth-daemon =
        {inherit (e.authDaemon) mode pam;}
        // lib.optionalAttrs (e.authDaemon.port != null) {inherit (e.authDaemon) port;};
    }
    // lib.optionalAttrs (e.mode == "inference") {
      ai-providers =
        map (p: {
          inherit (p) provider models;
          access-mode = p.accessMode;
          enabled = p.enable;
        })
        e.aiProviders;
      ai-budget =
        map (b: {
          inherit (b) amount unit period enforcement;
          enabled = b.enable;
        })
        e.aiBudgets;
    };
  privateAssertions = name: e: let
    nativeSSH = e.mode == "ssh" && e.authDaemon.mode == "native";
  in [
    {
      assertion = (allowed e || e.machines != []) && !lib.elem "Admin" e.roles;
      message = "Private Pangolin resource ${name} requires explicit users, roles or machines; do not list Admin.";
    }
    {
      assertion =
        (e.destination != null)
        == (!nativeSSH && !lib.elem e.mode ["exit-node" "inference"])
        && (e.alias == null || lib.elem e.mode ["host" "ssh"])
        && (e.fullDomain != null) == usesDomain e
        && (e.mode != "http" || e.destinationPort != null)
        && (e.destinationPort == null || (e.mode == "http" || (e.mode == "ssh" && !nativeSSH)))
        && (e.scheme == null || e.mode == "http")
        && (e.ssl == null || usesDomain e)
        && (hasPortRestrictions e || (e.tcpPorts == [] && e.udpPorts == [] && !e.allowICMP));
      message = "Private Pangolin resource ${name} has a missing or incompatible destination, alias, domain, port or TLS setting.";
    }
    {
      assertion =
        e.mode
        != "ssh"
        || (e.alias
          != null
          && (e.authDaemon.mode != "remote" || e.authDaemon.port != null)
          && (e.authDaemon.mode == "remote" || builtins.length (lib.unique e.sites) <= 1)
          && lib.elem (destinationPort e) (tcpPorts e));
      message = "Private SSH resource ${name} needs an alias and TCP access to its destination port. Remote auth needs its daemon port; site and native auth support one site.";
    }
    {
      assertion =
        (e.mode == "inference" || (e.aiProviders == [] && e.aiBudgets == []))
        && lib.all (p: p.models == [] || p.accessMode == "select") e.aiProviders
        && builtins.length e.aiBudgets == builtins.length (lib.unique (map (b: "${b.unit}/${b.period}") e.aiBudgets));
      message = "Private Pangolin resource ${name}: AI options require inference mode, selected models require select access, and budget units and periods must be unique.";
    }
  ];
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
