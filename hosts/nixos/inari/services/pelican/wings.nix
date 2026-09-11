{
  pkgs,
  config,
  ...
}: let
  # Wings reads its whole configuration from one YAML file, node credentials
  # included. Rendering it through sops keeps the node token out of a
  # repository that is mirrored to a public forge, and produces a real file
  # rather than a store symlink.
  configFile = config.sops.templates."pelican-wings.yml".path;
in {
  sops.secrets = {
    pelican_wings_uuid.sopsFile = ../../secrets.yaml;
    pelican_wings_token_id.sopsFile = ../../secrets.yaml;
    pelican_wings_token.sopsFile = ../../secrets.yaml;
  };

  sops.templates."pelican-wings.yml".content = ''
    debug: false
    uuid: ${config.sops.placeholder.pelican_wings_uuid}
    token_id: ${config.sops.placeholder.pelican_wings_token_id}
    token: ${config.sops.placeholder.pelican_wings_token}
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
    # The panel runs on this machine. Going out through the public hostname
    # meant resolving it against the local AdGuard, which has no record for it
    # -- wings died with "no such host" on every start.
    remote: 'http://127.0.0.1:${toString config.yomi.ports.pelican-panel}'
  '';

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
      WorkingDirectory = "/var/lib/pelican";
      ExecStart = "${pkgs.pelican-wings}/bin/wings --config ${configFile}";
      Restart = "on-failure";
      RestartSec = "5s";
      LimitNOFILE = 4096;
      RuntimeDirectory = "wings";
    };

    wantedBy = ["multi-user.target"];
  };

  yomi.cloudflared.at.wings = {
    port = config.yomi.ports.pelican-node1;
    enableAnubis = false;
  };

  yomi.nginx.at.wings-local = {
    port = config.yomi.ports.pelican-node1;
  };

  # networking.firewall is disabled on this host; see ../../networking/nftables.nix
  # for what is actually reachable.

  # Only the server volumes need to survive a rollback. /etc/pelican used to be
  # listed here as well, which bind-mounted an empty directory over the config
  # NixOS had just written -- that is why wings never found a config file.
  systemd.tmpfiles.rules = ["d /var/lib/pelican/volumes 0700 root root -"];
  environment.persistence."/persist/state".directories = ["/var/lib/pelican"];

  environment.systemPackages = [pkgs.pelican-wings];
}
