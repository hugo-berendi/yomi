{
  config,
  lib,
  ...
}: let
  cfg = config.yomi.externalHeartbeat;
  domain = config.yomi.dns.domain;
  host = "heartbeat.${domain}";
  state = "/var/lib/yomi/external-heartbeat";
  service = "yomi-heartbeat";
  port = 8524;
  mailAddress = "no-reply@tengu.hugo-berendi.de";
in {
  options.yomi.externalHeartbeat.enable = lib.mkEnableOption ''
    an independent Healthchecks instance with SMTP alert delivery.
    Provision `secret-key` and `smtp-password` under ${state}, readable
    by the healthchecks group, before enabling it
  '';

  config = lib.mkIf cfg.enable {
    services.healthchecks = {
      enable = true;
      inherit port;
      listenAddress = "127.0.0.1";
      settings = {
        ALLOWED_HOSTS = [host];
        SITE_NAME = "Yomi Heartbeat";
        SITE_ROOT = "https://${host}";
        REGISTRATION_OPEN = false;
        SECRET_KEY_FILE = "${state}/secret-key";
        EMAIL_HOST = "smtp.migadu.com";
        EMAIL_PORT = "465";
        EMAIL_USE_SSL = "True";
        EMAIL_HOST_USER = mailAddress;
        DEFAULT_FROM_EMAIL = mailAddress;
        EMAIL_HOST_PASSWORD_FILE = "${state}/smtp-password";
      };
    };

    # Keep both Python workers and migrations within one memory budget.
    systemd.slices.yomi-heartbeat.sliceConfig = {
      MemoryHigh = "320M";
      MemoryMax = "512M";
    };
    systemd.services =
      lib.genAttrs ["healthchecks" "healthchecks-migration" "healthchecks-sendalerts"] (_: {
        serviceConfig.Slice = "yomi-heartbeat.slice";
      })
      // {healthchecks-sendreports.enable = false;};

    systemd.tmpfiles.rules = ["d ${state} 0750 root healthchecks -"];

    services.traefik.dynamicConfigOptions.http = {
      routers.${service} = {
        entryPoints = ["websecure"];
        rule = "Host(`${host}`)";
        inherit service;
        tls.certResolver = "letsencrypt";
      };
      services.${service}.loadBalancer.servers = [
        {url = "http://127.0.0.1:${toString port}";}
      ];
    };

    yomi.dns.records = [
      {
        at = "heartbeat";
        type = "CNAME";
        value = "${config.yomi.expose.publicHost}.";
      }
    ];
  };
}
