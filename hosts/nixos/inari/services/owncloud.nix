{config, ...}: {
  # {{{ secrets
  sops.secrets.ocis_env = {
    sopsFile = ../secrets.yaml;
    owner = config.services.ocis.user;
    group = config.services.ocis.group;
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
