{
  config,
  lib,
  ...
}: let
  cfg = config.yomi.acme;
in {
  options.yomi.acme = {
    enable = lib.mkEnableOption "yomi's ACME integration";
    sopsFile = lib.mkOption {
      type = lib.types.path;
      description = "Encrypted file containing cloudflare_dns_api_token.";
    };
    email = lib.mkOption {
      type = lib.types.str;
      description = "ACME account contact address.";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets.cloudflare_dns_api_token.sopsFile = cfg.sopsFile;
    sops.templates."acme.env".content = ''
      CF_DNS_API_TOKEN=${config.sops.placeholder.cloudflare_dns_api_token}
    '';

    security.acme.acceptTerms = true;
    security.acme.defaults = {
      inherit (cfg) email;
      dnsProvider = "cloudflare";
      environmentFile = config.sops.templates."acme.env".path;
      renewInterval = "monthly";
    };

    environment.persistence."/persist/state".directories = [
      "/var/lib/acme"
    ];
  };
}
