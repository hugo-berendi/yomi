{config, ...}: {
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
    };

    scrapeConfigs = [
      {
        job_name = "inari";
        static_configs = [
          {
            targets = [
              "127.0.0.1:${toString config.services.prometheus.exporters.node.port}"
              "127.0.0.1:${toString config.services.prometheus.exporters.nginx.port}"
            ];
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
  # }}}
}
