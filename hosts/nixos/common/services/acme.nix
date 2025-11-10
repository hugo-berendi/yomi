{
  config,
  lib,
  ...
}: let
  cfg = config.yomi.acme;
in {
  options.yomi.acme = {
    enable = lib.mkEnableOption "yomi's ACME integration";
  };

  config = lib.mkIf cfg.enable {
    sops.secrets.cloudflare_dns_api_token.sopsFile = ../../secrets.yaml;
    sops.templates."acme.env".content = ''
      CF_DNS_API_TOKEN=${config.sops.placeholder.cloudflare_dns_api_token}
    '';

    security.acme.acceptTerms = true;
    security.acme.defaults = {
      email = "acme@hugo-berendi.de";
      dnsProvider = "cloudflare";
      environmentFile = config.sops.templates."acme.env".path;
      renewInterval = "monthly";
    };

    environment.persistence."/persist/state".directories = [
      "/var/lib/acme"
    ];
  };
}
