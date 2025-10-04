{config, ...}: {
  sops.secrets.guacamole_users.sopsFile = ../../secrets.yaml;
  yomi.nginx.at.guacamole.port = config.yomi.ports.guacamole;

  virtualisation.oci-containers.containers.guacamole = {
    image = "flcontainers/guacamole";
    autoStart = false;
    ports = ["${toString config.yomi.nginx.at.guacamole.port}:8080"];
    volumes = [
      "/etc/localtime:/etc/localtime"
      "${config.sops.secrets.guacamole_users.path}:/etc/guacamole/user-mapping.xml"
      "/var/lib/guacamole:/config"
    ];

    environment.TZ = config.time.timeZone;
  };

  users.users.pilot.openssh.authorizedKeys.keyFiles = [./ed25519.pub];
}
