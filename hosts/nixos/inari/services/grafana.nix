{
  config,
  lib,
  pkgs,
  ...
}: let
  port = config.yomi.ports.grafana;
  secret = name: "$__file{${config.sops.secrets.${name}.path}}";
  sopsSettings = {
    sopsFile = ../secrets.yaml;
    owner = "grafana";
  };

  backupAlert = {
    host,
    backup,
    maxAge,
  }: let
    selector = ''yomi_restic_last_success_timestamp_seconds{host="${host}",backup="${backup}"}'';
    lookback =
      if host == "amaterasu"
      then "8d"
      else "1h";
  in {
    uid = "${host}-${backup}-stale";
    title = "${host}: ${backup} overdue";
    condition = "C";
    data = [
      {
        refId = "A";
        relativeTimeRange = {
          from = 600;
          to = 0;
        };
        datasourceUid = "prometheus";
        model = {
          # Retain laptop successes through sleep; absent series must alert too.
          expr = "((time() - max(last_over_time(${selector}[${lookback}]))) > bool ${toString maxAge}) or absent_over_time(${selector}[${lookback}])";
          instant = true;
          refId = "A";
        };
      }
      {
        refId = "C";
        datasourceUid = "__expr__";
        model = {
          type = "threshold";
          expression = "A";
          conditions = [
            {
              evaluator = {
                type = "gt";
                params = [0];
              };
            }
          ];
          refId = "C";
        };
      }
    ];
    noDataState = "Alerting";
    execErrState = "Alerting";
    for = "15m";
    labels.severity = "warning";
    annotations.summary = "No successful ${backup} run on ${host} within ${toString (maxAge / 3600)} hours.";
  };

  # {{{ Dashboards provisioned as code
  nodeExporterFullDashboard = pkgs.fetchurl {
    url = "https://grafana.com/api/dashboards/1860/revisions/45/download";
    sha256 = "11hrll7fm626ikbva5md4gm0rca537vp4xsxa9sxl1pk15s6nk0q";
  };

  dashboardsDir = pkgs.linkFarm "inari-grafana-dashboards" [
    {
      name = "node-exporter-full.json";
      path = nodeExporterFullDashboard;
    }
  ];
  # }}}
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

      alerting.rules.settings = {
        apiVersion = 1;
        groups = [
          {
            orgId = 1;
            name = "inari-infrastructure";
            folder = "Alerts";
            interval = "5m";
            rules =
              (map backupAlert [
                {
                  host = "inari";
                  backup = "data";
                  maxAge = 30 * 3600;
                }
                {
                  host = "inari";
                  backup = "state";
                  maxAge = 30 * 3600;
                }
                {
                  host = "inari";
                  backup = "offsite";
                  maxAge = 30 * 3600;
                }
                {
                  host = "inari";
                  backup = "offsite-check";
                  maxAge = 8 * 86400;
                }
                {
                  host = "inari";
                  backup = "offsite-restore";
                  maxAge = 35 * 86400;
                }
                {
                  host = "amaterasu";
                  backup = "data";
                  maxAge = 7 * 86400;
                }
                {
                  host = "amaterasu";
                  backup = "state";
                  maxAge = 7 * 86400;
                }
              ])
              ++ [
                {
                  uid = "inari-target-down";
                  title = "Prometheus target down";
                  condition = "C";
                  data = [
                    {
                      refId = "A";
                      relativeTimeRange = {
                        from = 600;
                        to = 0;
                      };
                      datasourceUid = "prometheus";
                      model = {
                        # Laptop sleep is expected; its backups have a separate age alert.
                        expr = ''up{job!="amaterasu-backups"} == bool 0'';
                        instant = true;
                        refId = "A";
                      };
                    }
                    {
                      refId = "C";
                      datasourceUid = "__expr__";
                      model = {
                        type = "threshold";
                        expression = "A";
                        conditions = [
                          {
                            evaluator = {
                              type = "gt";
                              params = [0];
                            };
                          }
                        ];
                        refId = "C";
                      };
                    }
                  ];
                  noDataState = "OK";
                  execErrState = "Alerting";
                  for = "5m";
                  labels.severity = "warning";
                  annotations.summary = "{{ $labels.job }}/{{ $labels.instance }} has been down for 5 minutes.";
                }
                {
                  uid = "inari-disk-space-low";
                  title = "Disk space low";
                  condition = "C";
                  data = [
                    {
                      refId = "A";
                      relativeTimeRange = {
                        from = 600;
                        to = 0;
                      };
                      datasourceUid = "prometheus";
                      model = {
                        expr = ''min by (instance, mountpoint) (node_filesystem_avail_bytes{fstype!~"tmpfs|overlay"} / node_filesystem_size_bytes{fstype!~"tmpfs|overlay"})'';
                        instant = true;
                        refId = "A";
                      };
                    }
                    {
                      refId = "C";
                      datasourceUid = "__expr__";
                      model = {
                        type = "threshold";
                        expression = "A";
                        conditions = [
                          {
                            evaluator = {
                              type = "lt";
                              params = [0.1];
                            };
                          }
                        ];
                        refId = "C";
                      };
                    }
                  ];
                  noDataState = "OK";
                  execErrState = "Alerting";
                  for = "10m";
                  labels.severity = "warning";
                  annotations.summary = "{{ $labels.mountpoint }} on {{ $labels.instance }} has less than 10% free space.";
                }
                {
                  uid = "inari-zfs-pool-degraded";
                  title = "ZFS pool degraded";
                  condition = "C";
                  data = [
                    {
                      refId = "A";
                      relativeTimeRange = {
                        from = 600;
                        to = 0;
                      };
                      datasourceUid = "prometheus";
                      model = {
                        expr = "max by (pool) (zfs_pool_health)";
                        instant = true;
                        refId = "A";
                      };
                    }
                    {
                      refId = "C";
                      datasourceUid = "__expr__";
                      model = {
                        type = "threshold";
                        expression = "A";
                        conditions = [
                          {
                            evaluator = {
                              type = "gt";
                              params = [0];
                            };
                          }
                        ];
                        refId = "C";
                      };
                    }
                  ];
                  noDataState = "OK";
                  execErrState = "Alerting";
                  for = "1m";
                  labels.severity = "critical";
                  annotations.summary = "ZFS pool {{ $labels.pool }} is not ONLINE.";
                }
                {
                  uid = "inari-smart-failure";
                  title = "Disk SMART health check failing";
                  condition = "C";
                  data = [
                    {
                      refId = "A";
                      relativeTimeRange = {
                        from = 600;
                        to = 0;
                      };
                      datasourceUid = "prometheus";
                      model = {
                        expr = "min by (device) (smartctl_device_smart_status)";
                        instant = true;
                        refId = "A";
                      };
                    }
                    {
                      refId = "C";
                      datasourceUid = "__expr__";
                      model = {
                        type = "threshold";
                        expression = "A";
                        conditions = [
                          {
                            evaluator = {
                              type = "lt";
                              params = [1];
                            };
                          }
                        ];
                        refId = "C";
                      };
                    }
                  ];
                  noDataState = "OK";
                  execErrState = "Alerting";
                  for = "1m";
                  labels.severity = "critical";
                  annotations.summary = "SMART health check is failing for {{ $labels.device }}.";
                }
              ];
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
