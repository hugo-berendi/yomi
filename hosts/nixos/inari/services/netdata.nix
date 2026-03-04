{
  config,
  pkgs,
  ...
}: let
  port = config.yomi.ports.netdata;
  healthNotify = pkgs.writeText "health_alarm_notify.conf" ''
    SEND_EMAIL="YES"
    DEFAULT_RECIPIENT_EMAIL="personal@hugo-berendi.de"
    EMAIL_SENDER="no-reply@tengu.hugo-berendi.de"
    sendmail="/run/wrappers/bin/sendmail"
  '';
  goDConfig = pkgs.writeText "go.d.conf" ''
    enabled: yes
    default_run: no
    modules:
      docker: yes
      logind: yes
      systemdunits: yes
      nvme: yes
      smartctl: yes
      sensors: yes
      zfspool: yes
      prometheus: no
  '';
  pythonDConfig = pkgs.writeText "python.d.conf" ''
    enabled: no
  '';
in {
  # {{{ Service
  services.netdata = {
    enable = true;
    package = pkgs.netdata.override {
      withCloudUi = false;
    };
    python.enable = false;
    configDir = {
      "health_alarm_notify.conf" = healthNotify;
      "go.d.conf" = goDConfig;
      "python.d.conf" = pythonDConfig;
    };
    config = {
      cloud = {
        enabled = "no";
      };
      registry = {
        enabled = "no";
      };
      web = {
        "bind to" = "127.0.0.1:${toString port}";
        "allow connections from" = "localhost *";
        "allow dashboard from" = "localhost *";
        "allow badges from" = "*";
      };
    };
  };
  # }}
  # {{{ Networking
  yomi.nginx.at.netdata.port = port;
  # }}
  # {{{ Persistence
  environment.persistence."/persist/state".directories = [
    {
      directory = "/var/lib/netdata";
      user = "netdata";
      group = "netdata";
    }
    {
      directory = "/var/lib/netdata/cloud.d";
      user = "netdata";
      group = "netdata";
    }
    {
      directory = "/var/cache/netdata";
      user = "netdata";
      group = "netdata";
    }
    {
      directory = "/var/log/netdata";
      user = "netdata";
      group = "netdata";
    }
  ];
  # }}
}
