{config, ...}: let
  port = config.yomi.ports.grafana;
  secret = name: "$__file{${config.sops.secrets.${name}.path}}";
  sopsSettings = {
    sopsFile = ../secrets.yaml;
    owner = "grafana";
  };
in {
  # {{{ Secrets
  sops.secrets.grafana_smtp_pass = sopsSettings;
  sops.secrets.grafana_discord_webhook = sopsSettings;
  # }}}
  # {{{ Service
  services.grafana = {
    enable = true;

    settings = {
      server = rec {
        domain = config.yomi.nginx.at.grafana.host;
        root_url = "https://${domain}";
        http_port = port;
      };

      smtp = rec {
        enabled = true;

        user = "grafana@tengu.hugo-berendi.de";
        from_name = "Grafana";
        from_address = user;

        host = "smtp.migadu.com:465";
        password = secret "grafana_smtp_pass";
        startTLS_policy = "NoStartTLS";
      };
    };

    provision = {
      enable = true;

      alerting.contactPoints.settings = {
        apiVersion = 1;
        contactPoints = [
          {
            name = "main";
            receivers = [
              {
                uid = "main_discord";
                type = "discord";
                settings.url = secret "grafana_discord_webhook";
                settings.message = ''
                  @everyone ✨ An issue occured :O ✨
                  {{ template "default.message" . }}
                '';
              }
              {
                uid = "main_email";
                type = "email";
                settings.addresses = "colimit@hugo-berendi.de";
              }
            ];
          }
        ];
      };

      alerting.policies.settings = {
        apiVersion = 1;
        policies = [
          {
            receiver = "main";
          }
        ];
      };

      datasources.settings = {
        apiVersion = 1;
        datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            access = "proxy";
            url = "https://prometheus.hugo-berendi.de";
          }
          {
            name = "Loki";
            type = "loki";
            access = "proxy";
            url = "http://127.0.0.1:${toString config.yomi.ports.loki}";
          }
        ];
      };
    };
  };
  # }}}
  # {{{ Networking & persistence
  yomi.nginx.at.grafana.port = port;

  environment.persistence."/persist/state".directories = [
    {
      directory = config.services.grafana.dataDir;
      user = "grafana";
      group = "grafana";
    }
  ];
  # }}}
}
