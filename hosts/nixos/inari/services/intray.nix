{
  inputs,
  config,
  ...
}: let
  username = "prescientmoon";
  apiPort = config.yomi.ports.intray-api;
  webPort = config.yomi.ports.intray-client;
in {
  imports = [inputs.intray.nixosModules.x86_64-linux.default];

  # {{{ Configure intray
  services.intray.production = {
    enable = true;
    api-server = {
      enable = true;
      port = apiPort;
      admins = [username];
    };
    web-server = {
      enable = true;
      port = webPort;
      api-url = config.yomi.nginx.at."api.intray".url;
    };
  };
  # }}}
  # {{{ Networking & storage
  yomi.nginx.at."intray".port = webPort;
  yomi.nginx.at."api.intray".port = apiPort;

  environment.persistence."/persist/state".directories = [
    "/www/intray/production/data"
  ];
  # }}}
}
