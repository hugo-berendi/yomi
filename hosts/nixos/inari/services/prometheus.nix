{
  config,
  lib,
  ...
}: {
  # {{{ Secrets
  sops.secrets = {
    radarr_api_key.sopsFile = ../secrets.yaml;
    sonarr_api_key.sopsFile = ../secrets.yaml;
    lidarr_api_key.sopsFile = ../secrets.yaml;
    prowlarr_api_key.sopsFile = ../secrets.yaml;
    bazarr_api_key.sopsFile = ../secrets.yaml;
    readarr_api_key.sopsFile = ../secrets.yaml;
  };
  # }}}
  # {{{ Service
  services.prometheus = {
    enable = true;
    port = config.yomi.ports.prometheus;
    webExternalUrl = config.yomi.nginx.at.prometheus.url;

    exporters = {
      node = {
        enable = true;
        enabledCollectors = ["systemd"];
        port = config.yomi.ports.prometheus-node-exporter;
      };

      nginx = {
        enable = true;
        port = config.yomi.ports.prometheus-nginx-exporter;
      };

      postgres = {
        enable = true;
        port = config.yomi.ports.prometheus-postgres-exporter;
        runAsLocalSuperUser = true;
      };

      zfs = {
        enable = true;
        port = config.yomi.ports.prometheus-zfs-exporter;
      };

      systemd = {
        enable = true;
        port = config.yomi.ports.prometheus-systemd-exporter;
      };

      smartctl = {
        enable = true;
        port = config.yomi.ports.prometheus-smartctl-exporter;
      };

      exportarr-radarr = {
        enable = true;
        port = config.yomi.ports.prometheus-exportarr-radarr;
        url = "http://127.0.0.1:${toString config.yomi.ports.radarr}";
        apiKeyFile = config.sops.secrets.radarr_api_key.path;
      };

      exportarr-sonarr = {
        enable = true;
        port = config.yomi.ports.prometheus-exportarr-sonarr;
        url = "http://127.0.0.1:${toString config.yomi.ports.sonarr}";
        apiKeyFile = config.sops.secrets.sonarr_api_key.path;
      };

      exportarr-lidarr = {
        enable = true;
        port = config.yomi.ports.prometheus-exportarr-lidarr;
        url = "http://127.0.0.1:${toString config.yomi.ports.lidarr}";
        apiKeyFile = config.sops.secrets.lidarr_api_key.path;
      };

      exportarr-prowlarr = {
        enable = true;
        port = config.yomi.ports.prometheus-exportarr-prowlarr;
        url = "http://127.0.0.1:${toString config.yomi.ports.prowlarr}";
        apiKeyFile = config.sops.secrets.prowlarr_api_key.path;
      };

      exportarr-bazarr = {
        enable = true;
        port = config.yomi.ports.prometheus-exportarr-bazarr;
        url = "http://127.0.0.1:${toString config.yomi.ports.bazarr}";
        apiKeyFile = config.sops.secrets.bazarr_api_key.path;
      };

      exportarr-readarr = {
        enable = true;
        port = config.yomi.ports.prometheus-exportarr-readarr;
        url = "http://127.0.0.1:${toString config.yomi.ports.readarr}";
        apiKeyFile = config.sops.secrets.readarr_api_key.path;
      };
    };

    scrapeConfigs = [
      {
        job_name = "inari-system";
        static_configs = [
          {
            targets = [
              "127.0.0.1:${toString config.services.prometheus.exporters.node.port}"
              "127.0.0.1:${toString config.services.prometheus.exporters.nginx.port}"
              "127.0.0.1:${toString config.services.prometheus.exporters.postgres.port}"
              "127.0.0.1:${toString config.services.prometheus.exporters.zfs.port}"
              "127.0.0.1:${toString config.services.prometheus.exporters.systemd.port}"
              "127.0.0.1:${toString config.services.prometheus.exporters.smartctl.port}"
            ];
          }
        ];
      }
      {
        job_name = "inari-media";
        static_configs = [
          {
            targets = [
              "127.0.0.1:${toString config.services.prometheus.exporters.exportarr-radarr.port}"
              "127.0.0.1:${toString config.services.prometheus.exporters.exportarr-sonarr.port}"
              "127.0.0.1:${toString config.services.prometheus.exporters.exportarr-lidarr.port}"
              "127.0.0.1:${toString config.services.prometheus.exporters.exportarr-prowlarr.port}"
              "127.0.0.1:${toString config.services.prometheus.exporters.exportarr-bazarr.port}"
              "127.0.0.1:${toString config.services.prometheus.exporters.exportarr-readarr.port}"
            ];
          }
        ];
      }
      {
        job_name = "loki";
        static_configs = [
          {
            targets = ["127.0.0.1:${toString config.yomi.ports.loki}"];
          }
        ];
      }
      {
        job_name = "prometheus";
        static_configs = [
          {
            targets = ["127.0.0.1:${toString config.services.prometheus.port}"];
          }
        ];
      }
    ];
  };
  # }}}
  # {{{ Networking & persistence
  yomi.nginx.at.prometheus.port = config.services.prometheus.port;

  environment.persistence."/persist/state".directories = [
    {
      directory = "/var/lib/prometheus2";
      user = "prometheus";
      group = "prometheus";
    }
  ];

  systemd.services.prometheus.serviceConfig = lib.mkMerge [
    (lib.mapAttrs (_: lib.mkForce) config.yomi.hardening.presets.standard)
    {ReadWritePaths = ["/var/lib/prometheus2"];}
  ];
  # }}}
}
