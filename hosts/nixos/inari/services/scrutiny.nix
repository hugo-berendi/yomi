{
  config,
  lib,
  ...
}: let
  port = config.yomi.ports.scrutiny;
in {
  # {{{ Reverse proxy
  yomi.nginx.at.scrutiny.port = port;
  # }}}
  # {{{ Service
  services.scrutiny = {
    enable = true;
    openFirewall = false;
    settings.web.listen.port = port;
    settings.web.listen.host = "127.0.0.1";
    collector.enable = true;
    collector.settings.api.endpoint = "http://127.0.0.1:${toString port}";
    influxdb.enable = true;
  };
  # }}}
  # {{{ User/Group - upstream uses DynamicUser; we want a stable UID for persistence and SMART access
  users.groups.scrutiny = {};
  users.users.scrutiny = {
    isSystemUser = true;
    group = "scrutiny";
    home = "/var/lib/scrutiny";
    extraGroups = ["disk"];
  };
  # }}}
  # {{{ Storage - migrate SMART history across reboots
  environment.persistence."/persist/state".directories = [
    {
      directory = "/var/lib/scrutiny";
      mode = "u=rwx,g=,o=";
      user = "scrutiny";
      group = "scrutiny";
    }
    {
      directory = "/var/lib/influxdb2";
      mode = "u=rwx,g=,o=";
      user = "influxdb2";
      group = "influxdb2";
    }
  ];

  systemd.services.scrutiny.serviceConfig = lib.mkMerge [
    (lib.mapAttrs (_: lib.mkForce) config.yomi.hardening.presets.standard)
    {
      DynamicUser = lib.mkForce false;
      User = "scrutiny";
      Group = "scrutiny";
      ReadWritePaths = ["/var/lib/scrutiny"];
      PrivateDevices = lib.mkOverride 40 false;
    }
  ];

  systemd.services.scrutiny-collector.serviceConfig = lib.mkMerge [
    (lib.mapAttrs (_: lib.mkForce) config.yomi.hardening.presets.standard)
    {
      DynamicUser = lib.mkForce false;
      User = "scrutiny";
      Group = "scrutiny";
      PrivateDevices = lib.mkOverride 40 false;
      ProtectSystem = lib.mkOverride 40 false;
    }
  ];
  # }}}
}
