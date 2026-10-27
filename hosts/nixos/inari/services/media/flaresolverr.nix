{config, ...}: {
  virtualisation.oci-containers.containers.flaresolverr = {
    image = (import ../../images.nix).flaresolverr;
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
