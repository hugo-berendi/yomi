{
  lib,
  allowedCountries,
}: let
  inherit (lib) mkOption types;
in {
  allowedCountries = mkOption {
    type = types.listOf (types.strMatching "[A-Z]{2}");
    default = allowedCountries;
    defaultText = lib.literalExpression "config.yomi.expose.allowedCountries";
    description = "Country allowlist; permitted countries pass to authentication, all other and unknown countries are denied.";
  };
  hostHeader = mkOption {
    type = types.nullOr types.str;
    default = null;
    description = "Override the backend Host header for applications with a canonical internal URL.";
  };
  labels = mkOption {
    type = types.listOf types.str;
    default = [];
    description = "Resource labels for filtering in Pangolin.";
  };
  additionalTargets = mkOption {
    default = [];
    description = "Additional backend targets for load balancing; incompatible with the single-backend Anubis wrapper.";
    type = types.listOf (types.submodule {
      options = {
        hostname = mkOption {
          type = types.str;
          description = "Address as seen from Newt.";
        };
        port = mkOption {
          type = types.port;
          description = "Backend port.";
        };
        method = mkOption {
          type = types.enum ["http" "https"];
          default = "http";
          description = "Backend protocol.";
        };
      };
    });
  };
  healthCheck = {
    enable = lib.mkEnableOption "backend HTTP health checks, independently of SSO and Anubis";
    path = mkOption {
      type = types.strMatching "/.*";
      default = "/";
      description = "Backend health path.";
    };
    interval = mkOption {
      type = types.ints.positive;
      default = 30;
      description = "Probe interval in seconds.";
    };
    timeout = mkOption {
      type = types.ints.positive;
      default = 5;
      description = "Probe timeout in seconds.";
    };
    status = mkOption {
      type = types.ints.between 100 599;
      default = 200;
      description = "Expected health response code.";
    };
  };
  allowAuthBypass = mkOption {
    type = types.bool;
    default = false;
    description = "Explicitly permit allow rules, which bypass all Pangolin authentication.";
  };
  blockedCountries = mkOption {
    type = types.listOf (types.strMatching "[A-Z]{2}");
    default = [];
    description = "Deny these ISO country codes before any custom allow/pass rules. Requires GeoIP on the gateway.";
  };
  blockedASNs = mkOption {
    type = types.listOf types.ints.positive;
    default = [];
    description = "Deny these autonomous system numbers before any custom allow/pass rules. Requires GeoIP and ASN data.";
  };
  rules = mkOption {
    default = [];
    description = "Ordered resource access rules. Allow bypasses authentication and requires allowAuthBypass.";
    type = types.listOf (types.submodule {
      options = {
        action = mkOption {
          type = types.enum ["deny" "pass" "allow"];
          default = "deny";
          description = "Block, continue to authentication, or bypass authentication.";
        };
        match = mkOption {
          type = types.enum ["ip" "cidr" "path" "method" "country" "country_is_not" "asn"];
          description = "Rule matcher. Country and ASN matchers require gateway GeoIP databases.";
        };
        value = mkOption {
          type = types.str;
          description = "Matcher value.";
        };
      };
    });
  };
}
