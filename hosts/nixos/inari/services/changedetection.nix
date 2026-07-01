{config, ...}: let
  dataDir = "/persist/state/var/lib/changedetection";
in {
  # {{{ Reverse proxy
  yomi.nginx.at.changedetection.port = config.yomi.ports.changedetection;
  # }}}
  # {{{ Container
  systemd.tmpfiles.rules = [
    "d ${dataDir} 0750 0 0 - -"
  ];

  virtualisation.oci-containers.containers.changedetection = {
    image = "ghcr.io/dgtlmoon/changedetection.io:latest";
    autoStart = true;
    ports = ["${toString config.yomi.nginx.at.changedetection.port}:5000"];
    volumes = ["${dataDir}:/datastore"];
    environment = {
      PORT = "5000";
      BASE_URL = config.yomi.nginx.at.changedetection.url;
    };
  };
  # }}}
}
