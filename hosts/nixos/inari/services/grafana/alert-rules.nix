# Grafana's alert rules for inari and the hosts that back up to it. Contact
# points, policies and the rest of Grafana are in ./default.nix.
_: let
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
    # service (and host) let the alert router merge reports of one outage.
    labels = {
      severity = "warning";
      service = "restic";
      inherit host;
    };
    annotations.summary = "No successful ${backup} run on ${host} within ${toString (maxAge / 3600)} hours.";
  };
in {
  services.grafana.provision.alerting.rules.settings = {
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
              # A backup of an empty or half-mounted path still succeeds,
              # so the age alerts above stay green. Compare each set's
              # latest snapshot with its own largest in eight days. A set
              # without history compares with itself and stays quiet, so
              # a new set or a fresh metric raises no false alarm.
              uid = "backup-shrunk";
              title = "Backup covers far less than last week";
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
                    expr = "(last_over_time(yomi_restic_last_snapshot_bytes[8d]) / max_over_time(yomi_restic_last_snapshot_bytes[8d])) < bool 0.5";
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
              for = "15m";
              # service (and host) let the alert router merge reports of one outage.
              labels = {
                severity = "warning";
                service = "restic";
              };
              annotations.summary = "The latest {{ $labels.backup }} snapshot on {{ $labels.host }} covers less than half the bytes of its largest in eight days. Check that its paths were mounted.";
            }
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
                    expr = ''up == bool 0'';
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
                          params = [0.2];
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
              # service (and host) let the alert router merge reports of one outage.
              labels = {
                severity = "warning";
                service = "storage";
              };
              annotations.summary = "{{ $labels.mountpoint }} on {{ $labels.instance }} has less than 20% free space. Review ZFS snapshots as well as live data.";
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
              # service (and host) let the alert router merge reports of one outage.
              labels = {
                severity = "critical";
                service = "zfs";
              };
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
              # service (and host) let the alert router merge reports of one outage.
              labels = {
                severity = "critical";
                service = "storage";
              };
              annotations.summary = "SMART health check is failing for {{ $labels.device }}.";
            }
          ];
      }
    ];
  };
}
