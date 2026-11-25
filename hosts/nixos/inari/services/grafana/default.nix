{
  config,
  lib,
  outputs,
  pkgs,
  ...
}: let
  port = config.yomi.ports.grafana;
  secret = name: "$__file{${config.sops.secrets.${name}.path}}";
  sopsSettings = {
    sopsFile = ../../secrets.yaml;
    owner = "grafana";
  };

  # {{{ Dashboards provisioned as code
  nodeExporterFullDashboard = pkgs.fetchurl {
    url = "https://grafana.com/api/dashboards/1860/revisions/45/download";
    sha256 = "11hrll7fm626ikbva5md4gm0rca537vp4xsxa9sxl1pk15s6nk0q";
  };

  dashboardsDir = pkgs.linkFarm "inari-grafana-dashboards" [
    {
      name = "yomi-infrastructure.json";
      path = import ./infrastructure-dashboard.nix {
        inherit lib pkgs;
        hosts = builtins.attrNames outputs.nixosConfigurations;
        statusUrl = config.yomi.web.at.status.url;
        topologyUrl = "${config.yomi.web.at.lab.url}/infrastruktur/";
      };
    }
    {
      name = "node-exporter-full.json";
      path = nodeExporterFullDashboard;
    }
  ];
  # }}}
in {
  imports = [./alert-rules.nix];

  # {{{ Ports
  yomi.ports = {
    grafana = 8412;
  };
  # }}}
  # {{{ Secrets
  sops.secrets.grafana_smtp_pass = sopsSettings;
  sops.secrets.grafana_discord_webhook = sopsSettings;
  # }}}
  # {{{ Service
  services.grafana = {
    enable = true;

    settings = {
      server = rec {
        domain = config.yomi.web.at.grafana.host;
        root_url = "https://${domain}";
        http_port = port;
      };

      security.secret_key = "$__file{${config.services.grafana.dataDir}/.secret_key}";

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
              # Discord is read later, which is the wrong shape for a backup
              # that has not run in two days. The spine turns those into a
              # push.
              #
              # It posts to the translating workflow, not to the spine
              # directly -- Grafana sends its own payload shape, and the
              # spine deliberately understands only one.
              {
                uid = "main_ntfy";
                type = "webhook";
                settings = {
                  url = "http://127.0.0.1:${toString config.yomi.ports.n8n}/webhook/grafana-alert";
                  httpMethod = "POST";
                };
              }
            ];
          }
          # Mail lives in its own contact point so only critical alerts reach
          # it. It used to sit in "main" beside Discord, which meant every
          # warning mailed too, and re-mailed at Grafana's default four-hour
          # repeat for as long as it fired. A laptop that is off for a week
          # keeps its backup alerts firing for that week, so that alone was
          # six mails a day. The Migadu plan allows twenty outgoing mails a
          # day for the whole account, and each of these also counted
          # inbound.
          {
            name = "mail";
            receivers = [
              {
                uid = "mail_email";
                type = "email";
                settings.addresses = "colimit@hugo-berendi.de";
              }
            ];
          }
        ];
        # Provisioning never removes an integration on its own; without this
        # the old receiver stays attached to "main" and keeps mailing.
        deleteContactPoints = [
          {
            orgId = 1;
            uid = "main_email";
          }
        ];
      };

      alerting.policies.settings = {
        apiVersion = 1;
        policies = [
          {
            orgId = 1;
            receiver = "main";
            routes = [
              # continue so a critical alert still reaches Discord and the
              # spine through the catch-all below; a matched route otherwise
              # stops routing there.
              {
                receiver = "mail";
                object_matchers = [["severity" "=" "critical"]];
                continue = true;
                repeat_interval = "24h";
              }
              {receiver = "main";}
            ];
          }
        ];
      };

      dashboards.settings = {
        apiVersion = 1;
        providers = [
          {
            name = "inari";
            type = "file";
            updateIntervalSeconds = 30;
            options.path = dashboardsDir;
          }
        ];
      };

      datasources.settings = {
        apiVersion = 1;
        datasources = [
          {
            uid = "prometheus";
            name = "Prometheus";
            type = "prometheus";
            access = "proxy";
            # Alerts must still evaluate when local DNS or the reverse proxy fails.
            url = "http://127.0.0.1:${toString config.yomi.ports.prometheus}";
            jsonData.manageAlerts = false;
          }
          {
            uid = "loki";
            name = "Loki";
            type = "loki";
            access = "proxy";
            url = "http://127.0.0.1:${toString config.yomi.ports.loki}";
            # Rules live in Grafana; Loki has no ruler API to discover.
            jsonData.manageAlerts = false;
          }
        ];
      };
    };
  };
  # }}}
  # {{{ Networking & persistence
  yomi.web.at.grafana = {
    transport = "nginx";
    authentication = "application";
    monitor.enable = true;
  };

  yomi.persistence.at.state.apps.grafana.directories = [
    {
      directory = config.services.grafana.dataDir;
      user = "grafana";
      group = "grafana";
    }
  ];

  systemd.services.grafana.serviceConfig = lib.mkMerge [
    {
      ProtectSystem = lib.mkForce "strict";
      PrivateMounts = true;
    }
    {ReadWritePaths = [config.services.grafana.dataDir];}
  ];

  system.activationScripts.grafana-secret-key =
    lib.stringAfter ["var"]
    ''
      secret_file="${config.services.grafana.dataDir}/.secret_key"
      if [ ! -f "$secret_file" ]; then
        mkdir -p "${config.services.grafana.dataDir}"
        ${lib.getExe pkgs.openssl} rand -hex 32 > "$secret_file"
        chown grafana:grafana "$secret_file"
        chmod 600 "$secret_file"
      fi
    '';
  # }}}
}
