{config, ...}: let
  dataDir = "/persist/state/var/lib/actual";
in {
  # {{{ Reverse proxy
  yomi.nginx.at.actual.port = config.yomi.ports.actual;
  # }}}
  # {{{ Container
  systemd.tmpfiles.rules = ["d ${dataDir}"];

  virtualisation.oci-containers.containers.actual = {
    image = "actualbudget/actual-server:latest";
    autoStart = false;
    ports = ["${toString config.yomi.nginx.at.actual.port}:5006"];
    volumes = ["${dataDir}:/data"];
  };
  # }}}
}
