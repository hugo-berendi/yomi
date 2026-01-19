{lib, ...}: {
  # {{{ Memory limits for heavy services
  systemd.services = {
    immich-server.serviceConfig = {
      MemoryMax = "4G";
      MemoryHigh = "3G";
    };

    immich-machine-learning.serviceConfig = {
      MemoryMax = "4G";
      MemoryHigh = "3G";
    };

    jellyfin.serviceConfig = {
      MemoryMax = "4G";
      MemoryHigh = "3G";
    };

    home-assistant.serviceConfig = {
      MemoryMax = "2G";
      MemoryHigh = "1536M";
    };

    paperless-scheduler.serviceConfig = {
      MemoryMax = "2G";
      MemoryHigh = "1536M";
    };

    paperless-consumer.serviceConfig = {
      MemoryMax = "2G";
      MemoryHigh = "1536M";
    };

    paperless-web.serviceConfig = {
      MemoryMax = "2G";
      MemoryHigh = "1536M";
    };

    paperless-task-queue.serviceConfig = {
      MemoryMax = "2G";
      MemoryHigh = "1536M";
    };

    loki.serviceConfig = {
      MemoryMax = "2G";
      MemoryHigh = "1536M";
    };

    grafana.serviceConfig = {
      MemoryMax = "1G";
      MemoryHigh = "768M";
    };

    prometheus.serviceConfig = {
      MemoryMax = "2G";
      MemoryHigh = "1536M";
    };

    forgejo.serviceConfig = {
      MemoryMax = "1G";
      MemoryHigh = "768M";
    };

    postgresql.serviceConfig = {
      MemoryMax = "4G";
      MemoryHigh = "3G";
    };

    invidious.serviceConfig = {
      MemoryMax = "1G";
      MemoryHigh = "768M";
    };
  };
  # }}}

  # {{{ Higher swappiness for servers with many services
  boot.kernel.sysctl."vm.swappiness" = lib.mkForce 30;
  # }}}

  # {{{ Prometheus retention limits
  services.prometheus.extraFlags = [
    "--storage.tsdb.retention.time=30d"
    "--storage.tsdb.retention.size=10GB"
  ];
  # }}}
}
