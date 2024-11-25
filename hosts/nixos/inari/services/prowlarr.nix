{config, ...}: {
  services = {
    prowlarr = {
      enable = true;
    };
  };

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

  # This is the default port, and can only be changed via the GUI
  yomi.nginx.at.prowlarr.port = 9696;

  systemd.tmpfiles.rules = ["z /var/lib/private 0700 root"];

  environment.persistence."/persist/state".directories = [
    {
      directory = "/var/lib/private";
      mode = "0700";
    }
  ];
}
