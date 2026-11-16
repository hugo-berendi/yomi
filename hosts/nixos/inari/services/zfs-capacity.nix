{pkgs, ...}: let
  alert = {
    uid,
    title,
    expr,
    severity ? "warning",
    noDataState ? "Alerting",
    summary,
  }: {
    inherit uid title;
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
          inherit expr;
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
    inherit noDataState;
    execErrState = "Alerting";
    for = "5m";
    labels = {
      inherit severity;
      service = "storage";
    };
    annotations.summary = summary;
  };
in {
  systemd.tmpfiles.rules = ["d /var/lib/restic-metrics 0755 root root -"];
  systemd.services.zfs-capacity = {
    description = "Export ZFS capacity and forgotten migration snapshots (read-only)";
    path = [pkgs.zfs];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.python3}/bin/python3 ${./zfs-capacity.py}";
      TimeoutStartSec = "2m";
      ProtectSystem = "strict";
      ReadWritePaths = ["/var/lib/restic-metrics"];
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };
  systemd.timers.zfs-capacity = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "2m";
      OnUnitActiveSec = "5m";
    };
  };
  services.grafana.provision.alerting.rules.settings.groups = [
    {
      orgId = 1;
      name = "inari-zfs-capacity";
      folder = "Alerts";
      interval = "1m";
      rules = map alert [
        {
          uid = "inari-zfs-capacity-warning";
          title = "ZFS pool above 80%";
          expr = "yomi_zfs_pool_capacity_percent >= bool 80";
          summary = "{{ $labels.pool }} is at least 80% full. Check snapshot retention as well as live data; Nix GC cannot release blocks held by snapshots.";
        }
        {
          uid = "inari-zfs-capacity-critical";
          title = "ZFS pool above 90%";
          expr = "yomi_zfs_pool_capacity_percent >= bool 90";
          severity = "critical";
          summary = "{{ $labels.pool }} is at least 90% full. Review snapshots now, before ZFS slop space blocks writes.";
        }
        {
          uid = "inari-zfs-migration-snapshot-old";
          title = "Migration snapshot needs review";
          noDataState = "OK";
          expr = "yomi_zfs_migration_snapshot_age_seconds > bool (14 * 86400)";
          # A pool without migration snapshots is the desired state.
          summary = "{{ $labels.snapshot }} is older than 14 days. Verify recovery and explicitly retire the migration snapshot; it can pin garbage-collected Nix paths.";
        }
        {
          uid = "inari-dataset-space-critical";
          title = "Dataset free space critical";
          expr = ''min by (instance, mountpoint) (node_filesystem_avail_bytes{fstype!~"tmpfs|overlay"} / node_filesystem_size_bytes{fstype!~"tmpfs|overlay"}) < bool 0.1'';
          severity = "critical";
          summary = "{{ $labels.mountpoint }} has less than 10% available space. Check pool capacity, quotas and snapshots before writes fail.";
        }
        {
          uid = "inari-zfs-capacity-stale";
          title = "ZFS capacity collector overdue";
          expr = "(time() - yomi_zfs_capacity_last_success_timestamp_seconds > bool 900) or absent(yomi_zfs_capacity_last_success_timestamp_seconds)";
          summary = "ZFS capacity collection has not succeeded for 15 minutes.";
        }
      ];
    }
  ];
}
