{config, ...}: let
  pocketIdUrl = config.yomi.cloudflared.at.pocket-id.url;
  ocisUrl = config.yomi.cloudflared.at.cloud.url;
in {
  # {{{ reverse proxy
  yomi.cloudflared.at.cloud.port = config.yomi.ports.owncloud;
  # }}}
  # {{{ secrets
  sops.secrets.ocis_oidc_client_id.sopsFile = ../secrets.yaml;
  sops.secrets.ocis_oidc_client_secret.sopsFile = ../secrets.yaml;

  sops.templates."ocis.env" = {
    content = ''
      WEB_OIDC_CLIENT_ID=${config.sops.placeholder."ocis_oidc_client_id"}
    '';
    owner = config.users.users.ocis.name;
    group = config.users.users.ocis.group;
  };
  # }}}
  # {{{ csp config
  environment.etc."ocis/csp.yaml".text = ''
    directives:
      child-src:
        - '''self'''
      connect-src:
        - '''self'''
        - 'blob:'
        - 'https://raw.githubusercontent.com/owncloud/awesome-ocis/'
        - '${pocketIdUrl}/'
      default-src:
        - '''none'''
      font-src:
        - '''self'''
      frame-ancestors:
        - '''none'''
      frame-src:
        - '''self'''
        - 'blob:'
        - 'https://embed.diagrams.net/'
      img-src:
        - '''self'''
        - 'data:'
        - 'blob:'
        - 'https://raw.githubusercontent.com/owncloud/awesome-ocis/'
      manifest-src:
        - '''self'''
      media-src:
        - '''self'''
      object-src:
        - '''self'''
        - 'blob:'
      script-src:
        - '''self'''
        - '''unsafe-inline'''
      style-src:
        - '''self'''
        - '''unsafe-inline'''
  '';
  # }}}
  # {{{ general config
  services.ocis = {
    enable = true;
    address = "0.0.0.0";
    port = config.yomi.ports.owncloud;
    url = ocisUrl;
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

      # Disable non-essential services (including idp since we use Pocket ID)
      OCIS_EXCLUDE_RUN_SERVICES = "search,idp";

      # OIDC configuration with Pocket ID
      OCIS_OIDC_ISSUER = pocketIdUrl;
      PROXY_OIDC_REWRITE_WELLKNOWN = "true";
      PROXY_AUTOPROVISION_ACCOUNTS = "true";
      PROXY_ROLE_ASSIGNMENT_DRIVER = "oidc";
      PROXY_USER_OIDC_CLAIM = "preferred_username";
      PROXY_CSP_CONFIG_FILE_LOCATION = "${config.services.ocis.configDir}/csp.yaml";
    };
    environmentFile = config.sops.templates."ocis.env".path;
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
