# TODO: Finish implementing
{config, ...}: let
  dataDir = "/persist/state/var/lib/actual";
in {
  yomi.nginx.at.valheim.port = config.yomi.ports.valheim;
  systemd.tmpfiles.rules = ["d ${dataDir}"];

  virtualisation.oci-containers.containers.valheim = {
    image = "ghcr.io/lloesche/valheim-server";
    autoStart = true;

    ports = ["${toString config.yomi.nginx.at.valheim.port}:5006"]; # server:docker
    volumes = ["${dataDir}:/data"]; # server:docker
  };
}
