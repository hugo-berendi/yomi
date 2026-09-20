{
  config,
  lib,
  ...
}: {
  # {{{ Service
  services.loki = {
    enable = true;
    configuration = {
      server.http_listen_port = config.yomi.ports.loki;
      auth_enabled = false;

      ingester = {
        lifecycler = {
          address = "127.0.0.1";
          ring = {
            kvstore.store = "inmemory";
            replication_factor = 1;
          };
          final_sleep = "0s";
        };
        chunk_idle_period = "1h";
        max_chunk_age = "1h";
        chunk_target_size = 999999;
        chunk_retain_period = "30s";
      };

      schema_config = {
        configs = [
          {
            from = "2024-01-01";
            store = "tsdb";
            object_store = "filesystem";
            schema = "v13";
            index = {
              prefix = "index_";
              period = "24h";
            };
          }
        ];
      };

      storage_config = {
        tsdb_shipper = {
          active_index_directory = "/var/lib/loki/tsdb-index";
          cache_location = "/var/lib/loki/tsdb-cache";
        };
        filesystem.directory = "/var/lib/loki/chunks";
      };

      limits_config = {
        reject_old_samples = true;
        reject_old_samples_max_age = "168h";
        allow_structured_metadata = false;
      };

      table_manager = {
        retention_deletes_enabled = false;
        retention_period = "0s";
      };

      compactor = {
        working_directory = "/var/lib/loki";
        compactor_ring.kvstore.store = "inmemory";
      };
    };
  };

  # }}}
  # {{{ Networking & persistence
  yomi.nginx.at.loki.port = config.services.loki.configuration.server.http_listen_port;

  environment.persistence."/persist/state".directories = [
    {
      directory = config.services.loki.dataDir;
      user = "loki";
      group = "loki";
    }
  ];

  systemd.services.loki.serviceConfig = lib.mkMerge [
    {
      ProtectSystem = lib.mkForce "strict";
      PrivateDevices = true;
      PrivateMounts = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      RestrictNamespaces = true;
      RestrictSUIDSGID = true;
      SystemCallArchitectures = "native";
    }
    {ReadWritePaths = [config.services.loki.dataDir];}
  ];
  # }}}
}
