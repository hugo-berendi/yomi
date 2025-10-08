{
  lib,
  pkgs,
  config,
  ...
}: {
  systemd.services.wings = {
    description = "Pelican Wings Daemon";
    after = ["docker.service" "network.target"];
    requires = ["docker.service"];
    serviceConfig = {
      User = "root";
      WorkingDirectory = "/etc/pelican";
      ExecStart = "${pkgs.pelican-wings}/bin/wings";
      Restart = "on-failure";
      RestartSec = "5s";
      LimitNOFILE = 4096;
      RuntimeDirectory = "wings";
      PIDFile = "/run/wings/daemon.pid";
    };

    wantedBy = ["multi-user.target"];
  };

  environment.etc."pelican/config.yml" = {
    text = ''
      debug: true
      uuid: 291ddb9e-d377-4270-af8a-b3e4a6dae708
      token_id: XelVnCDM6NOW3wkI
      token: ewJqrBCxesfDMtSvzTWA7okk0Z6ksCNDRFiD2nJ6r9Apn6MRWmgrVl5tf6FXfIC7
      api:
        host: 0.0.0.0
        port: ${toString config.yomi.ports.pelican-node1}
        ssl:
          enabled: false
        upload_limit: 256
      system:
        data: /var/lib/pelican/volumes
        sftp:
          bind_port: 2022
      docker:
        network:
          name: host
          network_mode: host
      allowed_mounts: []
      remote: 'https://pelican.hugo-berendi.de'
    '';

    mode = "0600";
    user = "root";
    group = "root";
  };

  yomi.nginx.at."node1.pelican".port = config.yomi.ports.pelican-node1;

  networking.firewall.allowedTCPPorts = [config.yomi.ports.pelican-node1 2022];

  environment.persistence."/persist/state".directories = [
    "/etc/pelican"
    "/var/lib/pelican"
  ];

  environment.systemPackages = [pkgs.pelican-wings];
}
