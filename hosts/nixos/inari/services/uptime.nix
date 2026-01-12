{
  config,
  lib,
  ...
}: {
  # {{{ User/Group
  users.groups.uptime-kuma = {};
  users.users.uptime-kuma = {
    isSystemUser = true;
    group = "uptime-kuma";
  };
  # }}}
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

  systemd.services.uptime-kuma.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = "uptime-kuma";
    Group = "uptime-kuma";
  };

  environment.persistence."/persist/state".directories = [
    {
      directory = "/var/lib/uptime-kuma";
      user = "uptime-kuma";
      group = "uptime-kuma";
      mode = "0700";
    }
  ];
  # }}}
}
