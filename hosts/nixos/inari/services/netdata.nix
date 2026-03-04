{
  config,
  pkgs,
  ...
}: let
  port = config.yomi.ports.netdata;
  healthNotify = pkgs.writeText "health_alarm_notify.conf" ''
    SEND_EMAIL="YES"
    DEFAULT_RECIPIENT_EMAIL="personal@hugo-berendi.de"
    EMAIL_SENDER="noreply@tengu.hugo-berendi.de"
  '';
in {
  # {{{ Service
  services.netdata = {
    enable = true;
    package = pkgs.netdata.override {
      withCloudUi = true;
    };
    configDir = {
      "health_alarm_notify.conf" = healthNotify;
    };
    config = {
      "plugin:freeipmi" = {
        "command options" = "ignore 43,44";
      };
      web = {
        "bind to" = "127.0.0.1:${toString port}";
      };
    };
  };
  # }}
  # {{{ Networking
  yomi.nginx.at.netdata.port = port;
  # }}
}
