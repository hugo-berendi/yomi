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
      OCIS_INSECURE = "true";
      SEARCH_EXTRACTOR_TYPE = "basic";
      OCIS_EXCLUDE_RUN_SERVICES = "search,thumbnails";
    };
  };
  # }}}
  # {{{ storage
  environment.persistence."/persist/state".directories = [
    {
      directory = config.services.ocis.configDir;
      user = config.users.users.ocis.name;
      group = config.users.users.ocis.group;
    }
  ];
  # }}}
}
