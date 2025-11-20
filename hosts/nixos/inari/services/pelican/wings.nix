{
  lib,
  pkgs,
  config,
  ...
}: {
  systemd.services.wings-network = {
    description = "Create Pelican Wings Docker Network";
    after = ["docker.service"];
    requires = ["docker.service"];
    before = ["wings.service"];
    path = [pkgs.docker];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      docker network inspect pelican_nw || docker network create --subnet 172.21.0.0/16 --driver bridge pelican_nw
    '';
    preStop = ''
      docker network rm pelican_nw || true
    '';
    wantedBy = ["multi-user.target"];
  };

  systemd.services.wings = {
    description = "Pelican Wings Daemon";
    after = ["docker.service" "network.target" "wings-network.service"];
    requires = ["docker.service" "wings-network.service"];
    serviceConfig = {
      User = "root";
      WorkingDirectory = "/etc/pelican";
      ExecStart = "${pkgs.pelican-wings}/bin/wings";
      Restart = "on-failure";
      RestartSec = "5s";
      LimitNOFILE = 4096;
      RuntimeDirectory = "wings";
    };

    wantedBy = ["multi-user.target"];
  };

  environment.etc."pelican/config.yml" = {
    text = ''
      debug: false
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
          name: pelican_nw
          network_mode: pelican_nw
      allowed_mounts: []
      remote: 'https://pelican.hugo-berendi.de'
    '';

    mode = "0600";
    user = "root";
    group = "root";
  };

  yomi.cloudflared.at.wings = {
    port = config.yomi.ports.pelican-node1;
    enableAnubis = false;
  };

  yomi.nginx.at.wings-local = {
    port = config.yomi.ports.pelican-node1;
  };

  networking.firewall.allowedTCPPorts = [config.yomi.ports.pelican-node1 2022];

  environment.persistence."/persist/state".directories = [
    "/etc/pelican"
    "/var/lib/pelican"
  ];

  environment.systemPackages = [pkgs.pelican-wings];
}
