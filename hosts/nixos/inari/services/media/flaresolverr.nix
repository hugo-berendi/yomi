{config, ...}: {
  virtualisation.oci-containers.containers.flaresolverr = {
    image = "ghcr.io/flaresolverr/flaresolverr:latest";
    autoStart = true;
    ports = [
      "${toString config.yomi.ports.flaresolverr}:8191"
    ];
    environment = {
      LOG_LEVEL = "info";
      LOG_HTML = "false";
      CAPTCHA_SOLVER = "hcaptcha-solver";
      TZ = config.time.timeZone;
    };
  };
}
