{config, ...}: let
  port = config.yomi.ports.commafeed;
  dataDir = "/persist/state/var/lib/commafeed";
in {
  systemd.tmpfiles.rules = ["d ${dataDir}"];
  yomi.nginx.at.rss.port = port;

  virtualisation.oci-containers.containers.commafeed = {
    image = "athou/commafeed:master-postgresql-jvm";

    ports = ["${toString port}:8082"]; # server:docker
    volumes = ["${dataDir}:/commafeed/data"]; # server:docker

    # the JVM is way too hungry
    entrypoint =
      builtins.toJSON
      ["java" "-Xmx64m" "-jar" "commafeed.jar" "server" "config.yml"];

    # https://github.com/Athou/commafeed/blob/master/commafeed-server/config.yml.example
    environment = {
      CF_APP_PUBLICURL = "https://${config.yomi.nginx.at.rss.host}";
      CF_APP_ALLOWREGISTRATIONS = "true"; # I already made an account
      CF_APP_MAXENTRIESAGEDAYS = "0"; # Fetch old entries

      # I randomly generated an user agent for this
      CF_APP_USERAGENT = "Mozilla/5.0 (iPhone; CPU iPhone OS 11_0_6; like Mac OS X) AppleWebKit/533.48 (KHTML, like Gecko)  Chrome/49.0.2557.162 Mobile Safari/602.0";
    };
  };
}
