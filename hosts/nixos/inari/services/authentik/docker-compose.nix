# Auto-generated using compose2nix v0.3.2-pre.
{ pkgs, lib, config, ... }:

{
  # Runtime
  virtualisation.podman = {
    enable = true;
    autoPrune.enable = true;
    dockerCompat = true;
  };

  # Enable container name DNS for all Podman networks.
  networking.firewall.interfaces = let
    matchAll = if !config.networking.nftables.enable then "podman+" else "podman*";
  in {
    "${matchAll}".allowedUDPPorts = [ 53 ];
  };

  virtualisation.oci-containers.backend = "podman";

  # Containers
  virtualisation.oci-containers.containers."authentik-postgresql" = {
    image = "docker.io/library/postgres:16-alpine";
    environment = {
      "AUTHENTIK_SECRET_KEY" = "hlEAWPyRj/xQFeEs70VRzCMHCU2D4inaGwXx4B2ogAMVEfqE4RnyzUN+CAIXy5SqE44Mqvg6VulOoZWN";
      "PG_PASS" = "LyID4cBmvOV2LcbE+868m0ik5QKQSfLWFPt5lnAjIxoVioA+";
      "POSTGRES_DB" = "authentik";
      "POSTGRES_PASSWORD" = "LyID4cBmvOV2LcbE+868m0ik5QKQSfLWFPt5lnAjIxoVioA+";
      "POSTGRES_USER" = "authentik";
    };
    environmentFiles = [
      "/home/hugob/projects/yomi/hosts/nixos/inari/services/authentik/.env"
    ];
    volumes = [
      "authentik_database:/var/lib/postgresql/data:rw"
    ];
    log-driver = "journald";
    extraOptions = [
      "--health-cmd=pg_isready -d \${POSTGRES_DB} -U \${POSTGRES_USER}"
      "--health-interval=30s"
      "--health-retries=5"
      "--health-start-period=20s"
      "--health-timeout=5s"
      "--network-alias=postgresql"
      "--network=authentik_default"
    ];
  };
  systemd.services."podman-authentik-postgresql" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "podman-network-authentik_default.service"
      "podman-volume-authentik_database.service"
    ];
    requires = [
      "podman-network-authentik_default.service"
      "podman-volume-authentik_database.service"
    ];
    partOf = [
      "podman-compose-authentik-root.target"
    ];
    wantedBy = [
      "podman-compose-authentik-root.target"
    ];
  };
  virtualisation.oci-containers.containers."authentik-redis" = {
    image = "docker.io/library/redis:alpine";
    environmentFiles = [
      "/home/hugob/projects/yomi/hosts/nixos/inari/services/authentik/.env"
    ];
    volumes = [
      "authentik_redis:/data:rw"
    ];
    cmd = [ "--save" "60" "1" "--loglevel" "warning" ];
    log-driver = "journald";
    extraOptions = [
      "--health-cmd=redis-cli ping | grep PONG"
      "--health-interval=30s"
      "--health-retries=5"
      "--health-start-period=20s"
      "--health-timeout=3s"
      "--network-alias=redis"
      "--network=authentik_default"
    ];
  };
  systemd.services."podman-authentik-redis" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "podman-network-authentik_default.service"
      "podman-volume-authentik_redis.service"
    ];
    requires = [
      "podman-network-authentik_default.service"
      "podman-volume-authentik_redis.service"
    ];
    partOf = [
      "podman-compose-authentik-root.target"
    ];
    wantedBy = [
      "podman-compose-authentik-root.target"
    ];
  };
  virtualisation.oci-containers.containers."authentik-server" = {
    image = "ghcr.io/goauthentik/server:2025.2.3";
    environment = {
      "AUTHENTIK_POSTGRESQL__HOST" = "postgresql";
      "AUTHENTIK_POSTGRESQL__NAME" = "authentik";
      "AUTHENTIK_POSTGRESQL__PASSWORD" = "LyID4cBmvOV2LcbE+868m0ik5QKQSfLWFPt5lnAjIxoVioA+";
      "AUTHENTIK_POSTGRESQL__USER" = "authentik";
      "AUTHENTIK_REDIS__HOST" = "redis";
      "AUTHENTIK_SECRET_KEY" = "hlEAWPyRj/xQFeEs70VRzCMHCU2D4inaGwXx4B2ogAMVEfqE4RnyzUN+CAIXy5SqE44Mqvg6VulOoZWN";
      "PG_PASS" = "LyID4cBmvOV2LcbE+868m0ik5QKQSfLWFPt5lnAjIxoVioA+";
    };
    environmentFiles = [
      "/home/hugob/projects/yomi/hosts/nixos/inari/services/authentik/.env"
    ];
    volumes = [
      "/home/hugob/projects/yomi/hosts/nixos/inari/services/authentik/custom-templates:/templates:rw"
      "/home/hugob/projects/yomi/hosts/nixos/inari/services/authentik/media:/media:rw"
    ];
    ports = [
      "9000:9000/tcp"
      "9443:9443/tcp"
    ];
    cmd = [ "server" ];
    dependsOn = [
      "authentik-postgresql"
      "authentik-redis"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=server"
      "--network=authentik_default"
    ];
  };
  systemd.services."podman-authentik-server" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "podman-network-authentik_default.service"
    ];
    requires = [
      "podman-network-authentik_default.service"
    ];
    partOf = [
      "podman-compose-authentik-root.target"
    ];
    wantedBy = [
      "podman-compose-authentik-root.target"
    ];
  };
  virtualisation.oci-containers.containers."authentik-worker" = {
    image = "ghcr.io/goauthentik/server:2025.2.3";
    environment = {
      "AUTHENTIK_POSTGRESQL__HOST" = "postgresql";
      "AUTHENTIK_POSTGRESQL__NAME" = "authentik";
      "AUTHENTIK_POSTGRESQL__PASSWORD" = "LyID4cBmvOV2LcbE+868m0ik5QKQSfLWFPt5lnAjIxoVioA+";
      "AUTHENTIK_POSTGRESQL__USER" = "authentik";
      "AUTHENTIK_REDIS__HOST" = "redis";
      "AUTHENTIK_SECRET_KEY" = "hlEAWPyRj/xQFeEs70VRzCMHCU2D4inaGwXx4B2ogAMVEfqE4RnyzUN+CAIXy5SqE44Mqvg6VulOoZWN";
      "PG_PASS" = "LyID4cBmvOV2LcbE+868m0ik5QKQSfLWFPt5lnAjIxoVioA+";
    };
    environmentFiles = [
      "/home/hugob/projects/yomi/hosts/nixos/inari/services/authentik/.env"
    ];
    volumes = [
      "/home/hugob/projects/yomi/hosts/nixos/inari/services/authentik/certs:/certs:rw"
      "/home/hugob/projects/yomi/hosts/nixos/inari/services/authentik/custom-templates:/templates:rw"
      "/home/hugob/projects/yomi/hosts/nixos/inari/services/authentik/media:/media:rw"
      "/var/run/docker.sock:/var/run/docker.sock:rw"
    ];
    cmd = [ "worker" ];
    dependsOn = [
      "authentik-postgresql"
      "authentik-redis"
    ];
    user = "root";
    log-driver = "journald";
    extraOptions = [
      "--network-alias=worker"
      "--network=authentik_default"
    ];
  };
  systemd.services."podman-authentik-worker" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "podman-network-authentik_default.service"
    ];
    requires = [
      "podman-network-authentik_default.service"
    ];
    partOf = [
      "podman-compose-authentik-root.target"
    ];
    wantedBy = [
      "podman-compose-authentik-root.target"
    ];
  };

  # Networks
  systemd.services."podman-network-authentik_default" = {
    path = [ pkgs.podman ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "podman network rm -f authentik_default";
    };
    script = ''
      podman network inspect authentik_default || podman network create authentik_default
    '';
    partOf = [ "podman-compose-authentik-root.target" ];
    wantedBy = [ "podman-compose-authentik-root.target" ];
  };

  # Volumes
  systemd.services."podman-volume-authentik_database" = {
    path = [ pkgs.podman ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      podman volume inspect authentik_database || podman volume create authentik_database --driver=local
    '';
    partOf = [ "podman-compose-authentik-root.target" ];
    wantedBy = [ "podman-compose-authentik-root.target" ];
  };
  systemd.services."podman-volume-authentik_redis" = {
    path = [ pkgs.podman ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      podman volume inspect authentik_redis || podman volume create authentik_redis --driver=local
    '';
    partOf = [ "podman-compose-authentik-root.target" ];
    wantedBy = [ "podman-compose-authentik-root.target" ];
  };

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."podman-compose-authentik-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
    wantedBy = [ "multi-user.target" ];
  };
}
