{config, ...}: {
  yomi.cloudflared.at.uptime.port = config.yomi.ports.uptime-kuma;
  services.uptime-kuma = {
    enable = true;
    appriseSupport = true;
    settings = {
      # UPTIME_KUMA_HOST = "127.0.0.1";
      UPTIME_KUMA_PORT = builtins.toString config.yomi.cloudflared.at.uptime.port;
    };
  };
}
