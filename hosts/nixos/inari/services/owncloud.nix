{config, ...}: {
  # {{{ secrets
  sops.secrets.ocis_env = {
    sopsFile = ../secrets.yaml;
  };
  # }}}
  # {{{ reverse proxy
  yomi.nginx.at.cloud.port = config.yomi.ports.owncloud;
  # }}}
  # {{{ general config
  services.ocis = {
    enable = true;
    environmentFile = config.sops.secrets.ocis_env.path;
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

      # External OIDC (Authentik)
      OCIS_OIDC_ISSUER = "https://authentik.hugo-berendi.de/application/o/ocis/";
      PROXY_OIDC_ISSUER = "https://authentik.hugo-berendi.de/application/o/ocis/";
      PROXY_AUTOPROVISION_ACCOUNTS = "true";
      PROXY_ROLE_ASSIGNMENT_DRIVER = "oidc";
      
      # Web UI OIDC configuration  
      WEB_OIDC_METADATA_URL = "https://authentik.hugo-berendi.de/application/o/ocis/.well-known/openid-configuration";
      WEB_OIDC_AUTHORITY = "https://authentik.hugo-berendi.de/application/o/ocis";
      
      # Disable non-essential services
      OCIS_EXCLUDE_RUN_SERVICES = "search";
      PROXY_USER_OIDC_CLAIM = "preferred_username";
      PROXY_USER_CS3_CLAIM = "username";
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
