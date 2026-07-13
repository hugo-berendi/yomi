{lib, ...}: {
  # {{{ Memory limits for heavy services
  systemd.services =
    lib.mapAttrs (_: sc: {
      serviceConfig = lib.mapAttrs (_: lib.mkForce) sc;
    }) {
      immich-server = {
        MemoryMax = "4G";
        MemoryHigh = "3G";
      };

      immich-machine-learning = {
        MemoryMax = "4G";
        MemoryHigh = "3G";
      };

      jellyfin = {
        MemoryMax = "4G";
        MemoryHigh = "3G";
      };

      home-assistant = {
        MemoryMax = "2G";
        MemoryHigh = "1536M";
      };

      paperless-scheduler = {
        MemoryMax = "2G";
        MemoryHigh = "1536M";
      };

      paperless-consumer = {
        MemoryMax = "2G";
        MemoryHigh = "1536M";
      };

      paperless-web = {
        MemoryMax = "2G";
        MemoryHigh = "1536M";
      };

      paperless-task-queue = {
        MemoryMax = "2G";
        MemoryHigh = "1536M";
      };

      loki = {
        MemoryMax = "2G";
        MemoryHigh = "1536M";
      };

      grafana = {
        MemoryMax = "1G";
        MemoryHigh = "768M";
      };

      forgejo = {
        MemoryMax = "1G";
        MemoryHigh = "768M";
      };

      postgresql = {
        MemoryMax = "4G";
        MemoryHigh = "3G";
      };

      invidious = {
        MemoryMax = "1G";
        MemoryHigh = "768M";
      };
    };
  # }}}

  # {{{ Higher swappiness for servers with many services
  boot.kernel.sysctl."vm.swappiness" = lib.mkForce 30;
  # }}}
}
