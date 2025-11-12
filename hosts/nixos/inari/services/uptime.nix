{
  config,
  lib,
  ...
}: {
  # {{{ Reverse proxy
  yomi.cloudflared.at.uptime.port = config.yomi.ports.uptime-kuma;
  # }}}
  # {{{ Service
  services.uptime-kuma = {
    enable = true;
    appriseSupport = true;
    settings = {
      UPTIME_KUMA_PORT = builtins.toString config.yomi.cloudflared.at.uptime.port;
    };
  };
  
  systemd.services.uptime-kuma.serviceConfig.DynamicUser = lib.mkForce false;
  
  environment.persistence."/persist/state".directories = [
    "/var/lib/uptime-kuma"
  ];
  # }}}
}
