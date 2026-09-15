{config, ...}: {
  virtualisation.oci-containers.containers.flaresolverr = {
    image = "ghcr.io/flaresolverr/flaresolverr:latest@sha256:c80ae007ce2ccdcd217a12426e4f039ef763ff90738c808d38810c3e59323767";
    autoStart = true;
    ports = [
      "127.0.0.1:${toString config.yomi.ports.flaresolverr}:8191"
    ];
    environment = {
      LOG_LEVEL = "info";
      LOG_HTML = "false";
      CAPTCHA_SOLVER = "hcaptcha-solver";
      TZ = config.time.timeZone;
    };
  };
}
