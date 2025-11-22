{config, ...}: {
  # {{{ reverse proxy
  yomi.nginx.at.cloud.port = config.yomi.ports.owncloud;
  # }}}
  # {{{ general config
  services.ocis = {
    enable = true;
    address = "0.0.0.0";
    port = config.yomi.ports.owncloud;
    url = config.yomi.nginx.at.cloud.url;
    stateDir = "/raid5pool/cloud";
    configDir = "/var/lib/ocis/config";
    environment = {
      # Logging & observability
      OCIS_LOG_LEVEL = "info";
      OCIS_LOG_COLOR = "false";
      OCIS_LOG_PRETTY = "false";
      OCIS_TRACING_ENABLED = "false";

      # Performance & limits
      OCIS_MAX_CONCURRENT_REQUESTS = "0";
      OCIS_REQUEST_TIMEOUT = "0";

      # Disable TLS - nginx handles it
      OCIS_INSECURE = "true";
      PROXY_TLS = "false";

      # Disable non-essential services
      OCIS_EXCLUDE_RUN_SERVICES = "search,graph";
    };
  };
  # }}}
  # {{{ storage
  # Only persist configDir - stateDir is on /raid5pool which persists naturally
  environment.persistence."/persist/state".directories = [
    {
      directory = config.services.ocis.configDir;
      user = config.users.users.ocis.name;
      group = config.users.users.ocis.group;
    }
  ];
  # }}}
}
