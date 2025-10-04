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
      debug: false
      uuid: f81cd8a3-792e-4c6d-bdf7-4713a0334f7e
      token_id: XwhVdJDAKew0ZZYu
      token: SB06s7Nvf5yZaan8PsDsahv1VDq3TcAM3tEQ8izRA3CkHYyeCQ1PA6v9DrTXyU0z
      api:
        host: 0.0.0.0
        port: ${toString config.yomi.ports.pelican-node1}
        ssl:
          enabled: false
          cert: /etc/letsencrypt/live/node1.pelican.hugo-berendi.de/fullchain.pem
          key: /etc/letsencrypt/live/node1.pelican.hugo-berendi.de/privkey.pem
        upload_limit: 256
      system:
        data: /var/lib/pelican/volumes
        sftp:
          bind_port: 2022
      allowed_mounts: []
      remote: 'https://pelican.hugo-berendi.de'
    '';

    mode = "0600";
    user = "root";
    group = "root"; # Or potentially "docker" if needed, but root is safer
  };
  # yomi.nginx.at."node1.pelican".port = config.yomi.ports.pelican-node1;
  networking.firewall.allowedTCPPorts = [config.yomi.ports.pelican-node1 2022];

  environment.persistence."/persist/state".directories = [
    "/etc/pelican"
    "/var/lib/pelican"
  ];

  environment.systemPackages = [pkgs.pelican-wings];
}
